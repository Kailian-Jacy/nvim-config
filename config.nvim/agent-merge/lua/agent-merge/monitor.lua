-- agent-merge.monitor — layer 2: change analysis, base snapshots, save engine.
--
-- Sits between the raw change detector (agent-merge.watch, layer 1) and the
-- application policy (layer 3). It owns two things and decides nothing else:
--
--   * BASE SNAPSHOTS -- the last content at which a buffer and its file agreed.
--     Kept for EVERY buffer (observed or not); maintained by the glue layer at
--     sync points. The common ancestor for every 3-way merge.
--
--   * THE SAVE ENGINE (try_save) -- the ONLY path that writes to disk. Chained:
--     external edits that land while resolving are folded back in until a write
--     lands with no concurrent external change.
--
-- Classification (UpToDate / Changed / Conflict) is computed on demand, never
-- stored. "Deleted" is treated as a Conflict.

local watch = require("agent-merge.watch")
local merge = require("agent-merge.merge")

local M = {}

-- Bounds the try_save retry loop against pathological oscillation.
local MAX_ROUNDS = 16

--- buf -> string[]   base snapshot (durable; survives unobserve)
local bases = {}
--- buf -> { handle }  active observation (focused buffers only)
local obs = {}
--- buf -> { kind, n }  last-fired push state (for transition de-duplication)
local fired = {}

local cb_change ---@type fun(buf: integer)|nil
local cb_conflict ---@type fun(buf: integer, n: integer)|nil
local cb_sync ---@type fun(buf: integer)|nil

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function buf_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

--- @return string[]|nil  file lines, or nil if the file does not exist
local function read_lines(path)
  if vim.fn.filereadable(path) == 1 then
    return vim.fn.readfile(path)
  end
  return nil
end

local function eq(a, b)
  if a == b then return true end
  if not a or not b or #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

--- Write the buffer to its file using Neovim's own writer. `noautocmd` skips a
--- surrounding BufWriteCmd (no recursion) and BufWritePost; `!` bypasses
--- Neovim's own changed-file guard since try_save runs its own race check.
local function raw_write(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent noautocmd write!")
  end)
end

--- Persist the buffer only if the disk still holds the revision we resolved
--- against (`expect`, nil = expect the file to be absent). Returns false if the
--- agent wrote again in the meantime, so the caller re-enters the loop.
local function protected_write(buf, path, expect)
  local now = read_lines(path)
  if expect == nil then
    if now ~= nil then return false end
  elseif now == nil or not eq(now, expect) then
    return false
  end
  raw_write(buf)
  return true
end

---------------------------------------------------------------------------
-- base snapshot (durable per-buffer memory)
---------------------------------------------------------------------------

--- Set BASE := lines (default: current buffer). Call at every sync point.
--- Fires on_sync so the application layer knows the buffer is back in sync
--- (e.g. to resume autosave).
function M.snapshot(buf, lines)
  bases[buf] = lines or buf_lines(buf)
  if cb_sync then cb_sync(buf) end
end

--- @return string[]|nil
function M.base(buf)
  return bases[buf]
end

--- Compute the 3-way merge preview without saving (for a resolver UI).
--- @return string[] merged, integer conflicts
function M.merge_preview(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local base = bases[buf] or read_lines(path) or {}
  local disk = read_lines(path) or {}
  return merge.three_way(buf_lines(buf), base, disk)
end

--- Drop all memory for a buffer (call on BufDelete/BufWipeout).
function M.forget(buf)
  M.unobserve(buf)
  bases[buf] = nil
  fired[buf] = nil
end

---------------------------------------------------------------------------
-- classification (internal; on demand, never stored)
---------------------------------------------------------------------------

--- @return "UpToDate"|"Changed"|"Conflict" kind, integer n_conflicts
local function classify(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local base = bases[buf]
  local disk = read_lines(path)
  if base == nil then -- first sight: assume in sync with disk
    base = disk or {}
    bases[buf] = base
  end

  if disk == nil then
    return "Conflict", 0 -- deleted externally: never auto-resolve a deletion
  end
  if eq(disk, base) then
    return "UpToDate", 0
  end
  if eq(buf_lines(buf), base) then
    return "Changed", 0 -- buffer clean; adopting disk is trivially resolvable
  end
  local _, n = merge.three_way(buf_lines(buf), base, disk)
  if n <= 0 then
    return "Changed", 0
  end
  return "Conflict", n
end

---------------------------------------------------------------------------
-- save engine (the only writer; chained)
---------------------------------------------------------------------------

--- Save `buf` to disk, reconciling any external change. Chained: if the agent
--- writes again while we resolve, we re-merge and retry until the write lands
--- cleanly or a hook gives up.
--- @param buf integer
--- @param hooks? { if_changed?: fun():boolean, if_conflict?: fun(n:integer):boolean }
--- @return boolean saved
function M.try_save(buf, hooks)
  hooks = hooks or {}
  local path = vim.api.nvim_buf_get_name(buf)

  for _ = 1, MAX_ROUNDS do
    local mine = buf_lines(buf)
    local base = bases[buf] or read_lines(path) or {}
    local disk = read_lines(path)

    if disk == nil then
      -- Deleted externally => special conflict; default is to give up.
      local proceed = hooks.if_conflict and hooks.if_conflict(0) or false
      if not proceed then return false end
      if protected_write(buf, path, nil) then
        M.snapshot(buf, mine)
        return true
      end
      -- file reappeared during the hook; loop and re-evaluate
    elseif eq(disk, base) then
      -- No external change: persist the buffer as-is.
      if protected_write(buf, path, base) then
        M.snapshot(buf, mine)
        return true
      end
      -- raced with a fresh external write; loop
    else
      -- External change: 3-way merge to decide resolvability.
      local merged, n = merge.three_way(mine, base, disk)
      if n < 0 then return false end -- merge engine error

      local proceed
      if n == 0 then
        proceed = (hooks.if_changed == nil) or hooks.if_changed()
      else
        proceed = hooks.if_conflict and hooks.if_conflict(n) or false
      end
      if not proceed then return false end

      -- Adopt the resolved content atop the disk revision we just merged with.
      -- (n==0: we take `merged`; n>0: the caller resolved the buffer in-hook.)
      if n == 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
      end
      bases[buf] = disk
      -- loop: writes the now-local edits, re-merging if disk advanced again
    end
  end

  return false
end

--- Resolve an external change if (and only if) it is auto-resolvable, and save.
--- Equivalent to try_save with default hooks (proceed on Changed, give up on
--- Conflict). Never touches a conflicting buffer.
--- @return boolean saved
function M.auto_merge(buf)
  return M.try_save(buf)
end

---------------------------------------------------------------------------
-- observation + push callbacks (focused buffers only)
---------------------------------------------------------------------------

--- Classify and fire the appropriate push callback if the situation changed.
--- Exactly one callback per transition; re-fires when the conflict count moves.
local function dispatch(buf)
  local kind, n = classify(buf)
  local prev = fired[buf]

  if kind == "UpToDate" then
    fired[buf] = nil
  elseif kind == "Changed" then
    if not prev or prev.kind ~= "Changed" then
      fired[buf] = { kind = "Changed", n = 0 }
      if cb_change then cb_change(buf) end
    end
  else -- Conflict
    if not prev or prev.kind ~= "Conflict" or prev.n ~= n then
      fired[buf] = { kind = "Conflict", n = n }
      if cb_conflict then cb_conflict(buf, n) end
    end
  end
end

--- Start observing a buffer. Runs an immediate classification (state may be
--- stale after being unfocused) and fires if needed.
--- @param opts? { poll_ms?: integer }
--- @return boolean started
function M.observe(buf, opts)
  M.unobserve(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local handle = watch.watch(path, function()
    if vim.api.nvim_buf_is_valid(buf) and obs[buf] then
      dispatch(buf)
    end
  end, opts)
  if not handle then return false end
  obs[buf] = { handle = handle }
  dispatch(buf)
  return true
end

function M.unobserve(buf)
  local o = obs[buf]
  if o then
    watch.unwatch(o.handle)
    obs[buf] = nil
    fired[buf] = nil
  end
end

function M.unobserve_all()
  for buf in pairs(obs) do
    M.unobserve(buf)
  end
end

--- @return boolean
function M.observing(buf)
  return obs[buf] ~= nil
end

--- Register the push callback: observed file became auto-resolvable (Changed).
--- Never auto-merges; that is the caller's decision.
function M.on_change(fn)
  cb_change = fn
end

--- Register the push callback: observed file conflicts (n hunks; Deleted ⇒ n=0).
function M.on_conflict(fn)
  cb_conflict = fn
end

--- Register the callback fired when a buffer returns to sync (new base created).
function M.on_sync(fn)
  cb_sync = fn
end

return M
