-- agent-merge — reconcile concurrent edits between you and an external agent.
--
-- Layered architecture:
--   layer 1  agent-merge.watch     raw change detection (inotify / poll)
--   layer 2  agent-merge.monitor   base snapshots, change analysis, save engine
--   layer 3  (application)         autosave control, prompts, resolver UI
--
-- This module is the glue:
--   * maintains BASE snapshots for every file buffer at sync points
--     (BufReadPost / BufWritePost), independent of observation;
--   * aligns observation with focus (BufEnter/FocusGained ↔ BufLeave), which is
--     what makes "focused == fresh, unfocused == stale" hold and keeps at most
--     one live inotify watcher;
--   * forwards monitor's push callbacks to the layer-3 seams config.on_change /
--     config.on_conflict (default no-ops).

local watch = require("agent-merge.watch")
local monitor = require("agent-merge.monitor")

local M = {}
-- Re-export the engine so the application layer drives it directly.
M.monitor = monitor
M.try_save = monitor.try_save
M.auto_merge = monitor.auto_merge
M.observe = monitor.observe
M.unobserve = monitor.unobserve
M.snapshot = monitor.snapshot
M.base = monitor.base

M.config = {
  poll_ms = watch.DEFAULT_POLL_MS,
  --- Layer-3 seams (already scheduled on the main loop). Defaults are no-ops.
  --- on_change never auto-merges; the application decides what to do.
  on_change = function(_) end, ---@type fun(buf: integer)
  on_conflict = function(_, _) end, ---@type fun(buf: integer, n: integer)
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

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  monitor.on_change(function(buf) M.config.on_change(buf) end)
  monitor.on_conflict(function(buf, n) M.config.on_conflict(buf, n) end)

  local grp = vim.api.nvim_create_augroup("AgentMerge", { clear = true })

  -- BASE snapshots for every file buffer, at points where buffer == disk.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = grp,
    callback = function(a)
      if watchable(a.buf) then monitor.snapshot(a.buf) end
    end,
  })

  -- Observation follows focus.
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = grp,
    callback = function(a) observe(a.buf) end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = grp,
    callback = function(a) monitor.unobserve(a.buf) end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = grp,
    callback = function(a) monitor.forget(a.buf) end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function() monitor.unobserve_all() end,
  })

  -- Prime already-open buffers, and observe the current one.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and watchable(buf) then
      monitor.snapshot(buf)
    end
  end
  observe(vim.api.nvim_get_current_buf())
end

return M
