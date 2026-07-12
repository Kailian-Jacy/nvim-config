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
local function present_view(buf, ctx)
  if cfg.on_conflict_resolve then
    cfg.on_conflict_resolve(buf, ctx)
  elseif cfg.conflict == "diffthis" then
    resolver.open(buf, ctx)
  else
    vim.notify(
      "Conflict in " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
        .. " — resolve the markers, then save.",
      vim.log.levels.WARN, { title = "agent-merge" }
    )
  end
end

-- Re-open the resolver view for an already-presented (markered) buffer.
local function reopen_view(buf)
  if cfg.on_conflict_resolve then
    cfg.on_conflict_resolve(buf, nil)
  elseif cfg.conflict == "diffthis" then
    resolver.open(buf, nil)
  end
end

--- Present the conflict: capture the three versions *before* touching the
--- buffer, seed it with markers (non-conflicts already auto-merged), adopt the
--- agent's version as the new base so a resolved save writes cleanly, then hand
--- off to the presentation.
local function present_conflict(buf)
  if has_markers(buf) then
    reopen_view(buf) -- already presented; just re-open the view
    return
  end
  local ours = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local path = vim.api.nvim_buf_get_name(buf)
  local theirs = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
  local base = monitor.base(buf) or {}
  local merged, n = monitor.merge_preview(buf)
  if n <= 0 then return end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
  monitor.set_base(buf, theirs)
  present_view(buf, { ours = ours, theirs = theirs, base = base })
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
  resolver.close(buf) -- no-op unless a diff resolver session is open
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

--- Manual save entry point (e.g. <leader><cr>). Marker-guarded: never writes an
--- unresolved conflict; folds in external changes; opens the resolver on a
--- fresh conflict.
--- @return boolean saved
function M.save(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if has_markers(buf) then
    present_conflict(buf) -- unresolved: re-open the resolver, do not write markers
    return false
  end
  return monitor.try_save(buf, {
    if_conflict = function()
      present_conflict(buf)
      return false -- resolve interactively, then save again
    end,
    -- if_changed defaults to proceed (auto-merge & save)
  })
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
