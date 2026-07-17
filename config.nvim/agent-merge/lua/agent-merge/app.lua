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

--- Situation-aware confirmation. Returns one of:
---   change   -> "automerge" | "overwrite" | "abort"
---   conflict -> "resolve"   | "overwrite" | "abort"
local function ask(kind, name, n)
  local msg, choices, default_action
  if kind == "conflict" then
    msg = string.format("%s: conflicting external change (%d hunk%s).", name, n, n == 1 and "" or "s")
    choices = "&Resolve\n&Overwrite (discard external)\nA&bort"
    default_action = { "resolve", "overwrite", "abort" }
  else
    msg = string.format("%s changed on disk (auto-mergeable).", name)
    choices = "Auto-&merge\n&Overwrite (discard external)\nA&bort"
    default_action = { "automerge", "overwrite", "abort" }
  end
  local c = vim.fn.confirm(msg, choices, 1, kind == "conflict" and "Warning" or "Question")
  return default_action[c] or "abort" -- c==0 (Esc) => abort
end

--- Manual save entry point (e.g. <leader><cr> and :w via BufWriteCmd).
--- No external change  -> normal chained save.
--- External change     -> confirm (auto-merge/overwrite/abort) unless
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
    decision = ask(n == 0 and "change" or "conflict", tail, n)
  end

  if decision == "automerge" then
    return monitor.try_save(buf) -- chained 3-way merge & write
  elseif decision == "resolve" then
    present_conflict(buf) -- markers / diff resolver, then save again
    return false
  elseif decision == "overwrite" then
    monitor.force_write(buf) -- our version wins, discard external
    return true
  end
  return false -- abort
end

--- Statusline component for the current buffer.
--- @return string
function M.status()
  local p = pending[vim.api.nvim_get_current_buf()]
  if not p then return "" end
  if p.kind == "conflict" then
    return cfg.show_conflict_count and string.format("[=%d]", p.n or 0) or "[=]"
  end
  return "[+]"
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
