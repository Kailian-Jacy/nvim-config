-- agent-merge — reconcile concurrent edits between you and an external agent.
--
-- Layered architecture:
--   layer 1  agent-merge.watch     raw change detection (inotify / kqueue / poll)
--   layer 2  agent-merge.monitor   base snapshots, disk access, guarded write
--   layer 3  agent-merge.app       decision flow, resolver, autosave, status
--
-- This module is the coordinator: it maintains BASE snapshots for every file
-- buffer at sync points, drives observation (aligned with focus, or all buffers
-- in "auto" load mode), and connects layer 2's signals to layer 3.

local watch = require("agent-merge.watch")
local monitor = require("agent-merge.monitor")
local app = require("agent-merge.app")

local M = {}
-- Re-export the engine + application entry points.
M.monitor = monitor
M.try_save = monitor.try_save
M.auto_merge = monitor.auto_merge
M.save = app.save ---@type fun(buf?: integer): boolean
M.status = app.status ---@type fun(): string

M.config = {
  poll_ms = watch.DEFAULT_POLL_MS,
  --- "auto" | "on_focus" | "manual" — when external changes are pulled in.
  load = "manual",
  --- Pause the auto-save.nvim fork while a buffer has a pending external
  --- change or an open resolve session.
  autosave = true,
  --- Route `:w` through the reconcile engine (BufWriteCmd). Falls back to a
  --- plain write if anything goes wrong, so saving can never break. Our write
  --- fires BufWritePre/Post itself, so write hooks compose normally.
  intercept_write = true,
  --- On a save over an external change, ask first:
  ---   change   -> merge / preview / overwrite / cancel
  ---   conflict -> resolve / overwrite / abort
  ---   deleted  -> recreate / cancel
  --- false = no prompt (auto-merge changes, open the resolver on conflict).
  confirm_external = true,
  --- Show the conflict hunk count in the statusline ([=5] vs [=]).
  show_conflict_count = false,
  --- Manual save mapping; false to skip (e.g. when a composite mapping calls
  --- require("agent-merge").save() itself).
  save_keymap = "<leader><cr>",
}

local function watchable(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return vim.bo[buf].buftype == ""
    and name ~= ""
    and not name:match("^%w+://")
    and vim.fn.filereadable(name) == 1
end

--- @return boolean  agent-merge is responsible for saving `buf` (a named file
--- buffer, existing on disk or not yet)
function M.handles(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  return vim.bo[buf].buftype == "" and name ~= "" and not name:match("^%w+://")
end

local function observe(buf)
  if watchable(buf) and not monitor.observing(buf) then
    monitor.observe(buf, { poll_ms = M.config.poll_ms })
  end
end

-- Route `:w` on a watched buffer through the reconcile engine. Buffer-local so
-- special buffers are untouched. Re-installed on setup so a module reload
-- never leaves a callback bound to the previous module instance.
local function attach_write(buf, force)
  if not M.config.intercept_write then return end
  if vim.b[buf].agent_merge_wcmd and not force then return end
  if not M.handles(buf) then return end
  vim.b[buf].agent_merge_wcmd = true
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = vim.api.nvim_create_augroup("AgentMergeWrite" .. buf, { clear = true }),
    buffer = buf,
    callback = function(a)
      -- Compare canonical paths: <afile> may go through a symlink while the
      -- buffer name is resolved (/tmp vs /private/tmp on macOS).
      local target = monitor.canon(vim.fn.expand("<afile>:p"))
      if target ~= monitor.canon(vim.api.nvim_buf_get_name(a.buf)) then
        -- `:w otherfile`: plain write, no merge
        vim.api.nvim_buf_call(a.buf, function()
          vim.cmd("noautocmd write! " .. vim.fn.fnameescape(target))
        end)
        return
      end
      local ok, err = pcall(app.save, a.buf)
      if not ok then -- internal error: never let a bug break saving
        vim.notify("agent-merge: " .. tostring(err) .. " — plain write used.",
          vim.log.levels.ERROR, { title = "agent-merge" })
        vim.api.nvim_buf_call(a.buf, function() vim.cmd("noautocmd write!") end)
        monitor.snapshot(a.buf)
      end
      -- If app.save returned false (abort / unresolved), the buffer stays
      -- modified, which by itself vetoes `:wq` (no error needed).
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  -- Own the external-change policy: an 'autoread' reload syncs a buffer to
  -- disk behind our back and produces phantom "pending merge" states.
  -- Consumers of the option (e.g. checktime autocmds) check it at call time.
  vim.o.autoread = false

  -- A previous instance (module reload) may still hold watchers.
  monitor.unobserve_all()

  app.setup(M.config)
  monitor.on_state(app.on_state)
  monitor.on_sync(app.on_sync)

  local grp = vim.api.nvim_create_augroup("AgentMerge", { clear = true })

  -- BASE snapshots at points where buffer == disk. Writes done by the engine
  -- snapshot the exact written lines themselves.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = grp,
    callback = function(a)
      if not M.handles(a.buf) then return end
      if not monitor.writing(a.buf) then monitor.snapshot(a.buf) end
      attach_write(a.buf)
      if M.config.load == "auto" or a.buf == vim.api.nvim_get_current_buf() then
        observe(a.buf)
      end
    end,
  })

  -- :file / :saveas: the base and watcher belong to the old path.
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = grp,
    callback = function(a)
      monitor.unobserve(a.buf)
      app.on_rename(a.buf)
      if M.config.load == "auto" or a.buf == vim.api.nvim_get_current_buf() then
        observe(a.buf)
      end
    end,
  })

  -- Observation follows focus (all modes observe the focused buffer).
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = grp,
    callback = function(a)
      observe(a.buf)
      app.on_focus(a.buf)
    end,
  })
  -- Focus-aligned modes drop the watcher on leave; "auto" keeps watching all.
  vim.api.nvim_create_autocmd("BufLeave", {
    group = grp,
    callback = function(a)
      if M.config.load ~= "auto" then monitor.unobserve(a.buf) end
    end,
  })

  -- Only drop memory when the content is really gone. (BufDelete also fires
  -- when a loaded buffer is merely unlisted.)
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = grp,
    callback = function(a) monitor.forget(a.buf) end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function() monitor.unobserve_all() end,
  })

  if M.config.save_keymap then
    vim.keymap.set("n", M.config.save_keymap, function() app.save() end,
      { desc = "agent-merge: reconcile & save" })
  end

  -- Prime already-open buffers. Keep an existing base (module reload); never
  -- take one from a modified buffer -- its content is not on disk.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and watchable(buf) then
      if monitor.base(buf) == nil and not vim.bo[buf].modified then
        monitor.snapshot(buf)
      end
      attach_write(buf, true)
      if M.config.load == "auto" then observe(buf) end
    end
  end
  observe(vim.api.nvim_get_current_buf())
end

return M
