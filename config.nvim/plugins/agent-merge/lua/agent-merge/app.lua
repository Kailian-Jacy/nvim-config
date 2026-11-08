-- agent-merge.app — layer 3: application policy.
--
-- Consumes layer-2 signals (on_state / on_sync) and turns them into behaviour.
-- The governing rule for manual saves: a human confirmation approves the
-- CURRENT plan -- the disk revision that was shown -- and only that may be
-- written. If the disk moved on before the write lands, the decision flow is
-- re-entered and the human asked again.
--
--   * AUTOSAVE  paused while a buffer has a pending external change or an open
--               resolve session. Implemented by injecting a `condition` into
--               the local auto-save.nvim fork (re-checked at every write).
--   * LOAD mode "auto"     -> auto_merge on every auto-mergeable change;
--               "on_focus" -> auto_merge a pending change when you focus it;
--               "manual"   -> never automatic; you drive it with a save.
--               (The auto modes keep their own silent-merge semantics.)
--   * CONFLICT  resolved in the built-in native 3-way diff resolver. SAVE in
--               the resolver commits the resolution; closing it rolls back.
--               The base is untouched until the resolution is written.
--   * STATUS    per-buffer statusline indicator: [+] external change (or
--               modified), [=] / [=N] conflict, [x] file deleted externally.

local monitor = require("agent-merge.monitor")
local merge = require("agent-merge.merge")
local resolver = require("agent-merge.resolver")

local M = {}

-- Re-confirmation rounds before giving up (each round is human-paced unless
-- confirm_external = false).
local MAX_ROUNDS = 16
local RECONFIRM = "The file changed on disk again before it could be written."

local cfg ---@type table          shared config (set in setup)
--- buf -> { kind = "external"|"change"|"conflict"|"deleted", n }
local pending = {}
--- buf -> { ours, theirs, base }  context of an open resolve session
local resolving = {}

local eq = monitor.eq

local function lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "agent-merge" })
end

local function has_markers(buf)
  for _, l in ipairs(lines(buf)) do
    if l:match("^<<<<<<< ") or l:match("^>>>>>>> ") then
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------
-- autosave control (local auto-save.nvim fork)
---------------------------------------------------------------------------

-- auto-save reads cnf.opts.condition(buf) live at save time. We compose a guard
-- that refuses to save a buffer with a pending external change or an open
-- resolve session (an autosave must never count as a confirmation). Installed
-- after auto-save loads (its setup would otherwise overwrite the condition).
local autosave_guarded = false

local function install_autosave_guard()
  if autosave_guarded then return end
  local ok, as_config = pcall(require, "auto-save.config")
  if not ok or not as_config.opts then return end
  local prev = as_config.opts.condition
  as_config.opts.condition = function(buf)
    if pending[buf] or resolver.active(buf) then return false end
    if vim.b[buf].autosave_disable then return false end
    return prev == nil or prev(buf)
  end
  autosave_guarded = true
end

---------------------------------------------------------------------------
-- dialogs
---------------------------------------------------------------------------

local function with_note(msg, note)
  return note and (note .. "\n" .. msg) or msg
end

--- @return "automerge"|"preview"|"overwrite"|"abort"
local function ask_change(note)
  local c = vim.fn.confirm(
    with_note("Auto-mergeable external changes detected", note),
    "[&M]erge\n[&P]review\n[&O]verwrite\n[&C]ancel",
    1, "Question")
  return ({ [1] = "automerge", [2] = "preview", [3] = "overwrite", [4] = "abort" })[c] or "abort"
end

--- @return "resolve"|"overwrite"|"abort"
local function ask_conflict(name, n, note)
  local msg = string.format("%s: conflicting external change (%d hunk%s).", name, n, n == 1 and "" or "s")
  local c = vim.fn.confirm(with_note(msg, note), "&Resolve\n&Overwrite (discard external)\nA&bort", 1, "Warning")
  return ({ [1] = "resolve", [2] = "overwrite", [3] = "abort" })[c] or "abort"
end

--- @return "recreate"|"abort"
local function ask_deleted(name, note)
  local c = vim.fn.confirm(with_note(name .. " was deleted on disk.", note),
    "&Recreate (write mine)\n&Cancel", 2, "Warning")
  return c == 1 and "recreate" or "abort"
end

--- @return "overwrite"|"abort"
local function ask_exists(name, note)
  local c = vim.fn.confirm(with_note(name .. " already exists on disk.", note),
    "&Overwrite\n&Cancel", 2, "Warning")
  return c == 1 and "overwrite" or "abort"
end

---------------------------------------------------------------------------
-- conflict resolution / preview
---------------------------------------------------------------------------

--- Open the resolver on `ctx` = { ours, theirs, base, merged, n }. The base is
--- NOT touched: the resolution only becomes real when it is written.
local function present_conflict(buf, ctx)
  resolving[buf] = { ours = ctx.ours, theirs = ctx.theirs, base = ctx.base }
  pending[buf] = { kind = "conflict", n = ctx.n }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, ctx.merged)
  resolver.open(buf, {
    ours = ctx.ours,
    theirs = ctx.theirs,
    on_abort = function(b) -- rollback: restore your content; stays pending
      if vim.api.nvim_buf_is_valid(b) then
        vim.api.nvim_buf_set_lines(b, 0, -1, false, ctx.ours)
      end
      resolving[b] = nil
    end,
  })
end

--- Preview an auto-merge: apply the merge to the buffer (undoable; nothing is
--- written and the base is untouched) and open a codediff view of
--- current -> merged. Saving afterwards writes it without a second prompt as
--- long as the disk is unchanged (the buffer then already contains it).
local function preview_merge(buf, ours, merged)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)

  -- TODO: Once codediff can render a diff from in-buffer/Lua content directly
  -- (an `open`-style API taking the two line-lists instead of on-disk files),
  -- drop the temp-file write + deferred delete below.
  -- :CodeDiff file-diff is the public API of the pinned codediff (v2.52.0).
  local f_ours, f_merged = vim.fn.tempname(), vim.fn.tempname()
  vim.fn.writefile(ours, f_ours)
  vim.fn.writefile(merged, f_merged)
  local ok = pcall(vim.cmd,
    "CodeDiff file " .. vim.fn.fnameescape(f_ours) .. " " .. vim.fn.fnameescape(f_merged))
  if not ok then
    pcall(vim.fn.delete, f_ours)
    pcall(vim.fn.delete, f_merged)
    notify("codediff.nvim unavailable — merge applied to the buffer without a preview.")
    return
  end
  -- codediff's side-by-side view never sets a filetype; propagate the source
  -- buffer's onto the two diff buffers (located by their temp-file names).
  local src_ft = vim.bo[buf].filetype
  if src_ft and src_ft ~= "" then
    vim.defer_fn(function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local n = vim.api.nvim_buf_get_name(b)
        if n == f_ours or n == f_merged then
          pcall(function() vim.bo[b].filetype = src_ft end)
        end
      end
    end, 30)
  end
  vim.defer_fn(function()
    pcall(vim.fn.delete, f_ours)
    pcall(vim.fn.delete, f_merged)
  end, 5000)
end

---------------------------------------------------------------------------
-- the decision flow
---------------------------------------------------------------------------

--- Decide and write. Every write is guarded by the disk revision the decision
--- was made against; a moved disk re-enters the loop (and re-asks).
--- @return boolean saved
local function reconcile(buf, note)
  local path = vim.api.nvim_buf_get_name(buf)
  local tail = vim.fn.fnamemodify(path, ":t")
  local ask = cfg.confirm_external

  for _ = 1, MAX_ROUNDS do
    local mine = lines(buf)
    local disk = monitor.read_disk(buf, path)
    local base = monitor.base(buf)
    local bp = monitor.base_path(buf)
    local same_target = bp == nil or bp == monitor.canon(path)

    if disk == nil then
      if base == nil or not same_target then
        -- New file (never on disk for this buffer, or renamed): just create it.
        if monitor.write_if(buf, false) then return true end
      else
        if not ask then
          notify(tail .. " was deleted on disk; not recreating it.", vim.log.levels.WARN)
          return false
        end
        if ask_deleted(tail, note) ~= "recreate" then return false end
        if monitor.write_if(buf, false) then return true end
      end
    elseif base == nil then
      -- TODO(B2, deferred): unknown base, assume the disk is it.
      if monitor.write_if(buf, disk) then return true end
    elseif not same_target then
      -- Renamed onto an existing file (cf. E13): explicit overwrite only.
      if not ask then
        notify(tail .. " already exists; use :w! or confirm_external.", vim.log.levels.WARN)
        return false
      end
      if ask_exists(tail, note) ~= "overwrite" then return false end
      if monitor.write_if(buf, disk) then return true end
    elseif eq(disk, base) then
      -- No external change: persist the buffer as-is.
      if monitor.write_if(buf, disk) then return true end
    else
      local merged, n = merge.three_way(mine, base, disk)
      if n < 0 then
        notify("3-way merge failed (git merge-file); nothing was written.", vim.log.levels.ERROR)
        return false
      end
      if n == 0 and eq(merged, mine) then
        -- The buffer already contains the external change (e.g. after a
        -- Preview): nothing of theirs can be lost, write it.
        if monitor.write_if(buf, disk) then return true end
      else
        local decision
        if not ask then
          decision = (n == 0) and "automerge" or "resolve"
        else
          decision = (n == 0) and ask_change(note) or ask_conflict(tail, n, note)
        end

        if decision == "automerge" then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
          if monitor.write_if(buf, disk) then return true end
        elseif decision == "preview" then
          preview_merge(buf, mine, merged)
          return false -- review, then save again to persist
        elseif decision == "resolve" then
          present_conflict(buf, { ours = mine, theirs = disk, base = base, merged = merged, n = n })
          return false -- resolve, then save again to commit
        elseif decision == "overwrite" then
          if monitor.write_if(buf, disk) then return true end
        else
          return false -- abort
        end
      end
    end
    note = RECONFIRM -- the disk moved on between decision and write
  end

  notify(tail .. " keeps changing on disk; giving up for now.", vim.log.levels.WARN)
  return false
end

--- Save inside a resolve session = "the resolution is done": commit it against
--- the THEIRS revision the resolver showed.
local function commit(buf)
  local ctx = resolving[buf]
  if has_markers(buf) then
    notify("Unresolved conflict markers remain — resolve them, then save.", vim.log.levels.WARN)
    return false
  end
  if monitor.write_if(buf, ctx.theirs) then return true end -- on_sync ends the session
  -- The agent wrote again meanwhile. The confirmed resolution is relative to
  -- THEIRS, so adopt that as the base and run the normal flow again.
  resolver.finish(buf)
  resolving[buf] = nil
  monitor.set_base(buf, ctx.theirs)
  return reconcile(buf, RECONFIRM)
end

---------------------------------------------------------------------------
-- layer-2 signal handlers
---------------------------------------------------------------------------

function M.on_state(buf, state)
  if state == nil then
    if not resolving[buf] then pending[buf] = nil end
    return
  end
  if state.kind == "external" then
    -- Unclassified edit: keep a known classification until the settle pass.
    if not pending[buf] then pending[buf] = state end
    return
  end
  if resolving[buf] and state.kind ~= "deleted" then return end -- resolver owns it
  pending[buf] = state
  if state.kind == "change" and cfg.load == "auto" then
    monitor.auto_merge(buf)
  end
end

function M.on_sync(buf)
  pending[buf] = nil
  resolving[buf] = nil
  resolver.finish(buf) -- no-op unless a resolve session is open
end

--- Buffer renamed (:file / :saveas): its pending state belonged to the old path.
function M.on_rename(buf)
  if resolver.active(buf) then resolver.abort(buf) end
  pending[buf] = nil
end

--- Called by the glue when a buffer gains focus ("on_focus" load mode).
function M.on_focus(buf)
  if cfg.load == "on_focus" and pending[buf] then
    monitor.auto_merge(buf)
  end
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------

--- Manual save entry point (:w via BufWriteCmd, <leader><CR>).
--- In a resolve session: commit the resolution. Otherwise: write if the disk
--- is unchanged; on an external change ask (merge/preview/overwrite/abort, or
--- resolve/overwrite/abort on conflict) and write only what was confirmed.
--- @return boolean saved
function M.save(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if resolving[buf] and resolver.active(buf) then
    return commit(buf)
  end
  resolving[buf] = nil
  return reconcile(buf, nil)
end

--- Statusline component for the current buffer:
---   [x]       file deleted on disk
---   [=]/[=N]  conflict pending
---   [+]       external change pending, or modified (unsaved)
---   ""        clean & in sync
--- @return string
function M.status()
  local buf = vim.api.nvim_get_current_buf()
  local p = pending[buf]
  if p and p.kind == "deleted" then return "[x]" end
  if p and p.kind == "conflict" then
    return cfg.show_conflict_count and string.format("[=%d]", p.n or 0) or "[=]"
  end
  if p or vim.bo[buf].modified then
    return "[+]"
  end
  return ""
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

function M.setup(config)
  cfg = config

  if cfg.autosave then
    install_autosave_guard()
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("AgentMergeAutosave", { clear = true }),
      pattern = "LazyLoad",
      callback = function(a)
        if a.data == "auto-save.nvim" then install_autosave_guard() end
      end,
    })
  end
end

return M
