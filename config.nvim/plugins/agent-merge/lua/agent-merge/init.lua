-- agent-merge — reconcile concurrent edits between you and an external agent.
--
-- Layered architecture:
--   layer 1  agent-merge.watch     raw change detection (inotify / poll)
--   layer 2  agent-merge.monitor   base snapshots, change analysis, save engine
--   layer 3  agent-merge.app       autosave control, load modes, resolver, status
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
  --- Pause okuuva/auto-save.nvim while a buffer has a pending external change.
  autosave = true,
  --- Route `:w` through the reconcile engine (BufWriteCmd). Falls back to a
  --- plain write if anything goes wrong, so saving can never break. Our write
  --- fires BufWritePre/Post itself, so conform format-on-save and other write
  --- hooks compose normally (resolve -> BufWritePre -> write -> BufWritePost).
  intercept_write = true,
  --- On a manual save over an external change, pop a confirmation:
  ---   change  -> auto-merge / overwrite / abort
  ---   conflict-> resolve / overwrite / abort
  --- false = no prompt (auto-merge changes, open resolver on conflict).
  confirm_external = true,
  --- Conflict presentation: "markers" (git-style markers in the buffer) or
  --- "diffthis" (built-in native 3-way diff resolver, inline highlighting).
  conflict = "markers",
  --- Optional custom conflict resolver: fun(buf, ctx?) where ctx (nil on a bare
  --- re-open) = { ours, theirs, base }. Overrides `conflict` when set.
  on_conflict_resolve = nil,
  --- Show the conflict hunk count in the statusline ([=5] vs [=]).
  show_conflict_count = false,
  --- Manual save mapping; set to false to skip.
  save_keymap = "<leader><cr>",
}

local function watchable(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return vim.bo[buf].buftype == ""
    and name ~= ""
    and not name:match("^%w+://")
    and vim.fn.filereadable(name) == 1
end

local function observe(buf)
  if watchable(buf) and not monitor.observing(buf) then
    monitor.observe(buf, { poll_ms = M.config.poll_ms })
  end
end

-- Route `:w` on a watched buffer through the reconcile engine. Buffer-local so
-- special buffers are untouched; installed once per buffer.
local function attach_write(buf)
  if not M.config.intercept_write or vim.b[buf].agent_merge_wcmd then return end
  if not watchable(buf) then return end
  vim.b[buf].agent_merge_wcmd = true
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = vim.api.nvim_create_augroup("AgentMergeWrite" .. buf, { clear = true }),
    buffer = buf,
    callback = function(a)
      local target = vim.fs.normalize(vim.fn.expand("<afile>:p"))
      local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(a.buf))
      if target ~= bufname then -- `:w otherfile`: plain write, no merge
        vim.api.nvim_buf_call(a.buf, function()
          vim.cmd("noautocmd write! " .. vim.fn.fnameescape(target))
        end)
        return
      end
      local ok, err = pcall(app.save, a.buf)
      if not ok then -- internal error: never let a bug break saving
        vim.api.nvim_buf_call(a.buf, function() vim.cmd("noautocmd write!") end)
        -- The fallback wrote the buffer to disk behind the engine's back:
        -- resync the base or every later save sees a phantom external change
        -- (stale base, empty preview diff). And surface the swallowed error.
        monitor.snapshot(a.buf)
        vim.notify(
          "agent-merge: save pipeline failed, fell back to a plain write.\n" .. tostring(err),
          vim.log.levels.ERROR, { title = "agent-merge" }
        )
      end
      -- If app.save returned false (abort / unresolved), the buffer stays
      -- modified, which by itself vetoes `:wq` (no error needed).
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  -- Own the external-change policy: an 'autoread' reload syncs a buffer to
  -- disk via FileChangedShellPost (not BufReadPost), silently invalidating our
  -- BASE snapshot and producing phantom "pending merge" states. Consumers of
  -- the option (e.g. checktime autocmds) should check it at call time.
  vim.o.autoread = false

  app.setup(M.config)
  monitor.on_change(app.on_change)
  monitor.on_conflict(app.on_conflict)
  monitor.on_sync(app.on_sync)

  local grp = vim.api.nvim_create_augroup("AgentMerge", { clear = true })

  -- BASE snapshots for every file buffer, at points where buffer == disk.
  -- In "auto" mode we also observe on read so unfocused buffers are watched.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = grp,
    callback = function(a)
      if watchable(a.buf) then
        monitor.snapshot(a.buf)
        attach_write(a.buf)
        if M.config.load == "auto" then observe(a.buf) end
      end
    end,
  })

  -- Reloads that bypass BufReadPost (an 'autoread' reload or answering "Load"
  -- at the W11 prompt go through FileChangedShell(Post) only) sync the buffer
  -- to disk without updating BASE, leaving a stale base and phantom pending
  -- states. Re-snapshot at that sync point. ('autoread' is global-local, so
  -- `vim.o.autoread = false` above does not cover buffers where a plugin did
  -- `setlocal autoread`.)
  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = grp,
    callback = function(a)
      if not watchable(a.buf) or vim.bo[a.buf].modified then return end
      -- Only resync if the buffer was actually reloaded to the disk content;
      -- a pure timestamp notification (no reload) must keep the old ancestor.
      local disk = vim.fn.readfile(vim.api.nvim_buf_get_name(a.buf))
      local lines = vim.api.nvim_buf_get_lines(a.buf, 0, -1, false)
      if vim.deep_equal(disk, lines) then
        monitor.snapshot(a.buf, disk)
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

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
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

  -- Prime already-open buffers, and observe the current one.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and watchable(buf) then
      monitor.snapshot(buf)
      attach_write(buf)
      if M.config.load == "auto" then observe(buf) end
    end
  end
  observe(vim.api.nvim_get_current_buf())
end

return M
