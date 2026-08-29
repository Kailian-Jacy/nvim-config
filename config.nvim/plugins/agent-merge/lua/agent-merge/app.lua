-- agent-merge.app — layer 3: application policy.
--
-- Consumes layer-2 signals (on_change / on_conflict / on_sync) and turns them
-- into behaviour:
--
--   * AUTOSAVE  paused the moment a file changes externally (change OR conflict)
--               and resumed on the next sync (a new base). Implemented by
--               injecting a `condition` into okuuva/auto-save.nvim, per buffer.
--   * LOAD mode "auto"     -> auto_merge on every external change (any buffer);
--               "on_focus" -> auto_merge a pending change when you focus it;
--               "manual"   -> never automatic; you drive it (try_save).
--   * CONFLICT  presented either as git-style markers in the buffer, or via the
--               built-in native 3-way diff resolver (conflict = "markers" |
--               "diffthis"); the agent's version is adopted as the new base so a
--               resolved save writes cleanly. A custom resolver can be plugged
--               in via on_conflict_resolve(buf, ctx). (codediff.nvim's merge
--               mode is git-mergetool only -- it needs git index stages :2/:3 --
--               so it cannot resolve arbitrary on-disk divergences.)
--   * STATUS    per-buffer indicator for the statusline: [+] pending external
--               change, [=] / [=N] conflict.

local monitor = require("agent-merge.monitor")
local resolver = require("agent-merge.resolver")

local M = {}

local cfg ---@type table          shared config (set in setup)
--- buf -> { kind = "change"|"conflict", n }  drives autosave-hold + statusline
local pending = {}

local function eq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

---------------------------------------------------------------------------
-- conflict markers
---------------------------------------------------------------------------

local function has_markers(buf)
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if l:match("^<<<<<<< ") or l:match("^>>>>>>> ") then
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------
-- autosave control (okuuva/auto-save.nvim)
---------------------------------------------------------------------------

-- auto-save reads cnf.opts.condition(buf) live at save time. We compose a guard
-- that refuses to save a buffer with a pending external change. Installed after
-- auto-save loads (its setup would otherwise overwrite the condition).
local autosave_guarded = false

local function install_autosave_guard()
  if autosave_guarded then return end
  local ok, as_config = pcall(require, "auto-save.config")
  if not ok or not as_config.opts then return end
  local prev = as_config.opts.condition
  as_config.opts.condition = function(buf)
    if pending[buf] then return false end -- external change pending: hold
    if vim.b[buf].autosave_disable then return false end
    return prev == nil or prev(buf)
  end
  autosave_guarded = true
end

---------------------------------------------------------------------------
-- conflict resolution (git-style markers; pluggable / built-in diff resolver)
---------------------------------------------------------------------------

-- Dispatch to the chosen presentation with the three versions in hand.
-- Seed the buffer for resolution and open the chosen presentation.
-- ctx = { ours, theirs, base, merged }.
local function present_view(buf, ctx)
  if cfg.on_conflict_resolve then
    cfg.on_conflict_resolve(buf, ctx) -- custom resolver decides its own seeding
  elseif cfg.conflict == "diffthis" then
    -- Markers mark the unresolved regions (so save is guarded and they're
    -- visible); the OURS/THEIRS panes give the word-level diff. Closing the
    -- tab aborts and restores, so nothing lingers.
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, ctx.merged)
    resolver.open(buf, {
      ours = ctx.ours,
      theirs = ctx.theirs,
      on_abort = function(b)
        vim.api.nvim_buf_set_lines(b, 0, -1, false, ctx.ours) -- discard attempt
        monitor.set_base(b, ctx.base)                          -- undo base:=disk
      end,
    })
  else
    -- Markers: represent both sides inline for text-based resolution.
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, ctx.merged)
    vim.notify(
      "Conflict in " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
        .. " — resolve the markers, then save.",
      vim.log.levels.WARN, { title = "agent-merge" }
    )
  end
end

-- Re-open the resolver view for an already-presented buffer.
local function reopen_view(buf)
  if cfg.on_conflict_resolve then
    cfg.on_conflict_resolve(buf, nil)
  elseif cfg.conflict == "diffthis" then
    resolver.open(buf, nil)
  end
end

--- Present a conflict: capture the three versions, adopt the agent's version as
--- the new base (so a resolved save writes cleanly), then hand off to the
--- presentation, which seeds the buffer (markers or marker-free) as appropriate.
local function present_conflict(buf)
  if has_markers(buf) then
    reopen_view(buf) -- already presented with markers; just re-open the view
    return
  end
  local ours = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local path = vim.api.nvim_buf_get_name(buf)
  local theirs = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  local base = monitor.base(buf) or {}
  local merged, n = monitor.merge_preview(buf)
  if n <= 0 then return end
  monitor.set_base(buf, theirs)
  present_view(buf, { ours = ours, theirs = theirs, base = base, merged = merged })
end

---------------------------------------------------------------------------
-- layer-2 signal handlers
---------------------------------------------------------------------------

function M.on_change(buf)
  pending[buf] = { kind = "change" }
  if cfg.load == "auto" then
    monitor.auto_merge(buf)
  end
end

function M.on_conflict(buf, n)
  -- Just record it (statusline [=]/[=N] + autosave hold). Resolution is driven
  -- by a save attempt, matching "manual" load semantics.
  pending[buf] = { kind = "conflict", n = n }
end

function M.on_sync(buf)
  pending[buf] = nil
  resolver.finish(buf) -- no-op unless a diff resolver session is open
end

--- Called by the glue when a buffer gains focus (definition of "focus" is the
--- glue's; here it only matters for the on_focus load mode).
function M.on_focus(buf)
  if cfg.load == "on_focus" and pending[buf] then
    monitor.auto_merge(buf)
  end
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------

--- Compact auto-merge confirmation. Returns one of:
---   "automerge" | "preview" | "overwrite" | "abort"
local function ask_change()
  local c = vim.fn.confirm(
    "Auto-mergeable external changes detected",
    "[&M]erge\n[&P]review\n[&O]verwrite\n[&C]ancel",
    1, "Question")
  -- c == 0 (Esc/Ctrl-C) => "abort"
  return ({ [1] = "automerge", [2] = "preview", [3] = "overwrite", [4] = "abort" })[c] or "abort"
end

--- Compact conflict confirmation. Returns one of:
---   "resolve" | "overwrite" | "abort"
local function ask_conflict(name, n)
  local msg = string.format("%s: conflicting external change (%d hunk%s).", name, n, n == 1 and "" or "s")
  local c = vim.fn.confirm(msg, "&Resolve\n&Overwrite (discard external)\nA&bort", 1, "Warning")
  return ({ [1] = "resolve", [2] = "overwrite", [3] = "abort" })[c] or "abort" -- c==0 (Esc) => abort
end

--- Preview an auto-merge: write the merged content into the buffer and open a
--- codediff view showing the change (current -> merged, i.e. current plus the
--- external edits). The buffer is rebased onto the external revision so a
--- follow-up save lands cleanly.
local function preview_merge(buf)
  local ours = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local path = vim.api.nvim_buf_get_name(buf)
  local theirs = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  local merged = monitor.merge_preview(buf)

  -- TODO: Once codediff can render a diff from in-buffer/Lua content directly
  -- (an `open`-style API taking the two line-lists instead of on-disk files),
  -- simplify this: drop the temp-file write + deferred delete below and pass
  -- ours/merged straight to that API.
  -- Apply the merge now (the preview *is* the merge).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
  monitor.set_base(buf, theirs)

  -- Diff current -> merged via codediff's :CodeDiff file-diff command. This is
  -- the public API of the pinned non-forked codediff (v2.52.0): it exposes the
  -- diff only as a command — its Lua module exports no `open` function (`open`
  -- only exists in a later/forked codediff). The view is fed from temp files so
  -- neither pane binds to the live buffer or on-disk file.
  local f_ours, f_merged = vim.fn.tempname(), vim.fn.tempname()
  vim.fn.writefile(ours, f_ours)
  vim.fn.writefile(merged, f_merged)
  local ok = pcall(vim.cmd,
    "CodeDiff file " .. vim.fn.fnameescape(f_ours) .. " " .. vim.fn.fnameescape(f_merged))
  if not ok then
    pcall(vim.fn.delete, f_ours)
    pcall(vim.fn.delete, f_merged)
    vim.notify("codediff.nvim unavailable — merge applied without a preview.",
      vim.log.levels.INFO, { title = "agent-merge" })
    return
  end
  -- codediff's side-by-side view ignores the filetype it is passed and never
  -- sets one, so the panes would render unhighlighted. Propagate the source
  -- buffer's authoritative filetype onto the two diff buffers — they are backed
  -- by our temp files, so we locate them by name.
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
  -- codediff loads both files into buffers on open; drop the temp files shortly
  -- after so the view keeps its in-memory content.
  vim.defer_fn(function()
    pcall(vim.fn.delete, f_ours)
    pcall(vim.fn.delete, f_merged)
  end, 5000)
end

--- Manual save entry point (e.g. <leader><cr> and :w via BufWriteCmd).
--- No external change  -> normal chained save.
--- Auto-mergeable change-> confirm (merge/preview/overwrite/abort) unless
---                        confirm_external=false, then auto behaviour.
--- Conflict            -> confirm (resolve/overwrite/abort).
--- Marker-guarded: never writes an unresolved conflict.
--- @return boolean saved
function M.save(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if has_markers(buf) then
    present_conflict(buf) -- unresolved markers: reopen resolver, do not write
    return false
  end

  local path = vim.api.nvim_buf_get_name(buf)
  local base = monitor.base(buf)
  local disk = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil

  -- Stale-base guard: if the buffer and the file already agree, any base
  -- divergence is stale memory (a reload/write that bypassed our sync points).
  -- Nothing can possibly need merging -- resync the base from disk and fall
  -- through to a normal save (which also resets 'modified'). Without this, a
  -- stale base produced a phantom "auto-mergeable external change" prompt
  -- whose preview diff is empty (merged == ours).
  if disk ~= nil and eq(disk, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    and (base == nil or not eq(disk, base)) then
    monitor.snapshot(buf, disk)
    base = disk
  end

  -- New file, untracked, or no external change: normal chained save.
  if base == nil or disk == nil or eq(disk, base) then
    return monitor.try_save(buf)
  end

  -- External change: classify, then decide.
  local _, n = monitor.merge_preview(buf)
  local tail = vim.fn.fnamemodify(path, ":t")
  local decision
  if not cfg.confirm_external then
    decision = (n == 0) and "automerge" or "resolve"
  else
    decision = (n == 0) and ask_change() or ask_conflict(tail, n)
  end

  if decision == "automerge" then
    return monitor.try_save(buf) -- chained 3-way merge & write
  elseif decision == "preview" then
    preview_merge(buf) -- codediff view; buffer now holds the merge
    return false -- review, then save again to persist
  elseif decision == "resolve" then
    present_conflict(buf) -- markers / diff resolver, then save again
    return false
  elseif decision == "overwrite" then
    monitor.force_write(buf) -- our version wins, discard external
    return true
  end
  return false -- abort
end

--- Statusline component for the current buffer:
---   [=]/[=N]  conflict pending
---   [+]       modified (unsaved) or a pending external change
---   ""        clean & in sync
--- @return string
function M.status()
  local buf = vim.api.nvim_get_current_buf()
  local p = pending[buf]
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
      pattern = "LazyLoad",
      callback = function(a)
        if a.data == "auto-save.nvim" then install_autosave_guard() end
      end,
    })
  end
end

return M
