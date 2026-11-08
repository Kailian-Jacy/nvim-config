-- agent-merge.monitor — layer 2: base snapshots, disk access, change signals.
--
-- Sits between the raw change detector (agent-merge.watch, layer 1) and the
-- application policy (layer 3, agent-merge.app). It owns mechanism only and
-- decides nothing:
--
--   * BASE SNAPSHOTS -- the content of the disk revision a buffer is derived
--     from, in BUFFER representation (after 'fileencoding' / 'fileformat'
--     decoding), plus the path it belongs to. Set only at points where the
--     buffer provably matches the disk: after a read, and to the exact lines
--     the engine wrote.
--
--   * DISK READS in the same representation (read_disk), so "disk == base" is
--     a like-for-like comparison (mixed EOL, latin1, empty files, ...).
--
--   * write_if -- the guarded writer: persist the buffer only if the disk
--     still holds the revision the caller decided against; otherwise report
--     "stale" and let the caller re-enter its decision flow.
--
--   * CHANGE SIGNALS -- a file event only establishes that SOMETHING changed
--     ({kind = "external"}, from a cheap stat). The content is classified once
--     the file has been quiet for SETTLE_MS, and that classification only
--     feeds the status display / auto modes; it never decides a write.
--
-- State lives in a global table so a module reload (:Lazy reload) keeps the
-- bases instead of re-priming them from possibly-modified buffers.

local watch = require("agent-merge.watch")
local merge = require("agent-merge.merge")

local uv = vim.uv or vim.loop

local M = {}

-- Bounds the auto-mode try_save retry loop against pathological oscillation.
local MAX_ROUNDS = 16
--- Quiet period after the last file event before the content is classified.
M.SETTLE_MS = 500

local S = _G.__agent_merge_state or {}
_G.__agent_merge_state = S
S.bases = S.bases or {}           -- buf -> string[]   base content
S.base_paths = S.base_paths or {} -- buf -> string     canonical path of the base
S.own_fp = S.own_fp or {}         -- buf -> table      stat right after our own write
S.obs = S.obs or {}               -- buf -> { handle, timer }
S.writing = S.writing or {}       -- buf -> true while the engine writes
local bases, base_paths, own_fp, obs, writing = S.bases, S.base_paths, S.own_fp, S.obs, S.writing

local cb_state ---@type fun(buf: integer, state: table|nil)|nil
local cb_sync ---@type fun(buf: integer)|nil

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function buf_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function eq(a, b)
  if a == b then return true end
  if not a or not b or #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end
M.eq = eq

--- Canonical path: symlinks resolved, also for a file that does not exist yet
--- (resolve its directory). Neovim stores resolved buffer names, while
--- <afile> and user input may still go through a symlink (/tmp on macOS).
function M.canon(path)
  if not path or path == "" then return path end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local real = uv.fs_realpath(path)
  if real then return real end
  local dir = uv.fs_realpath(vim.fs.dirname(path))
  if dir then return dir .. "/" .. vim.fs.basename(path) end
  return path
end

--- Read `path` in the representation `buf` holds it in (the inverse of what
--- :write does with 'fileencoding', 'fileformat' and 'bomb').
--- @return string[]|nil  lines, or nil if the file does not exist / is unreadable
function M.read_disk(buf, path)
  path = path or vim.api.nvim_buf_get_name(buf)
  if path == "" then return nil end
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a") or ""
  f:close()

  local bo = vim.bo[buf]
  local fenc = bo.fileencoding
  if fenc ~= "" and fenc ~= "utf-8" and fenc ~= "utf8" then
    local conv = vim.iconv(data, fenc, "utf-8")
    if conv then data = conv end -- on failure compare raw bytes (best effort)
  end
  if bo.bomb and data:sub(1, 3) == "\239\187\191" then data = data:sub(4) end

  local ff = bo.fileformat
  local sep = ff == "mac" and "\r" or "\n"
  local lines = vim.split(data, sep, { plain = true })
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end -- trailing EOL
  if ff == "dos" then
    for i, l in ipairs(lines) do
      if l:sub(-1) == "\r" then lines[i] = l:sub(1, -2) end
    end
  end
  for i, l in ipairs(lines) do
    if l:find("\0", 1, true) then lines[i] = l:gsub("%z", "\n") end -- NUL is NL in buffer lines
  end
  if #lines == 0 then lines = { "" } end -- an empty buffer still has one line
  return lines
end

local function fingerprint(path)
  local st = path and path ~= "" and uv.fs_stat(path)
  if not st then return nil end
  return {
    ino = st.ino, size = st.size,
    ms = st.mtime.sec, mn = st.mtime.nsec,
    cs = st.ctime.sec, cn = st.ctime.nsec,
  }
end

local function fp_eq(a, b)
  return a and b and a.ino == b.ino and a.size == b.size and a.ms == b.ms
    and a.mn == b.mn and a.cs == b.cs and a.cn == b.cn
end

--- Write the buffer to its file using Neovim's own writer. `noautocmd` skips a
--- surrounding BufWriteCmd (no recursion); `!` bypasses Neovim's changed-file
--- guard since write_if runs its own check.
local function raw_write(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent noautocmd write!")
  end)
end

-- Fire a write event on `buf` (we own the write, so Neovim won't fire these).
local function fire(buf, ev)
  vim.api.nvim_buf_call(buf, function()
    vim.api.nvim_exec_autocmds(ev, { buffer = buf })
  end)
end

---------------------------------------------------------------------------
-- base snapshot
---------------------------------------------------------------------------

local function stop_timer(buf)
  local o = obs[buf]
  if o and o.timer then
    pcall(function() o.timer:stop() end)
    pcall(function() o.timer:close() end)
    o.timer = nil
  end
end

--- Set BASE := lines (default: current buffer content) for the buffer's
--- current path. Call only where buffer == disk. Fires on_sync.
function M.snapshot(buf, lines)
  bases[buf] = lines or buf_lines(buf)
  base_paths[buf] = M.canon(vim.api.nvim_buf_get_name(buf))
  stop_timer(buf)
  if cb_sync then cb_sync(buf) end
end

--- @return string[]|nil
function M.base(buf)
  return bases[buf]
end

--- Canonical path the base belongs to (differs from the buffer's path after
--- :file / :saveas).
function M.base_path(buf)
  return base_paths[buf]
end

--- Set BASE without signalling on_sync (the buffer is still pending).
function M.set_base(buf, lines)
  bases[buf] = lines
end

--- @return boolean  true while the engine itself is writing `buf`
function M.writing(buf)
  return writing[buf] == true
end

--- Drop all memory for a buffer (BufWipeout / BufUnload).
function M.forget(buf)
  M.unobserve(buf)
  bases[buf], base_paths[buf], own_fp[buf] = nil, nil, nil
end

---------------------------------------------------------------------------
-- guarded write
---------------------------------------------------------------------------

local STALE = {}

--- Persist `buf` only if its file still holds `expect` (false = the file must
--- not exist). BufWritePre hooks run in between, so the disk is re-checked
--- after them. On success BASE := exactly the lines written.
--- The remaining check-to-write window is accepted.
--- @param expect string[]|false
--- @return boolean written  false = the disk moved on (caller re-decides)
function M.write_if(buf, expect)
  local path = vim.api.nvim_buf_get_name(buf)
  local function matches()
    local now = M.read_disk(buf, path)
    if expect == false then return now == nil end
    return now ~= nil and eq(now, expect)
  end
  if not matches() then return false end

  local written
  writing[buf] = true
  local ok, err = pcall(function()
    fire(buf, "BufWritePre")
    if not matches() then error(STALE) end
    local lines = buf_lines(buf) -- after BufWritePre hooks: what goes to disk
    raw_write(buf)
    written = lines
    own_fp[buf] = fingerprint(path)
    fire(buf, "BufWritePost")
  end)
  writing[buf] = nil
  if not ok and err ~= STALE and not written then error(err, 0) end
  if not written then return false end
  M.snapshot(buf, written)
  return true
end

---------------------------------------------------------------------------
-- classification (on demand; feeds display and auto modes only)
---------------------------------------------------------------------------

--- @return "UpToDate"|"Changed"|"Conflict"|"Deleted" kind, integer n
function M.classify(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local disk = M.read_disk(buf, path)
  local base = bases[buf]
  local same_target = base_paths[buf] == nil or base_paths[buf] == M.canon(path)

  if disk == nil then
    if base == nil or not same_target then return "UpToDate", 0 end -- new file
    return "Deleted", 0
  end
  if base == nil then
    -- TODO(B2, deferred): an unknown base is assumed to equal the disk.
    bases[buf], base_paths[buf] = disk, M.canon(path)
    return "UpToDate", 0
  end
  if not same_target then return "Conflict", 0 end -- renamed onto an existing file
  if eq(disk, base) then return "UpToDate", 0 end
  local mine = buf_lines(buf)
  if eq(mine, base) then return "Changed", 0 end
  local _, n = merge.three_way(mine, base, disk)
  if n == 0 then return "Changed", 0 end
  return "Conflict", math.max(n, 0)
end

local STATE = {
  UpToDate = function() return nil end,
  Changed = function() return { kind = "change" } end,
  Conflict = function(n) return { kind = "conflict", n = n } end,
  Deleted = function() return { kind = "deleted" } end,
}

local function settle(buf)
  stop_timer(buf)
  if not (vim.api.nvim_buf_is_valid(buf) and obs[buf]) then return end
  local kind, n = M.classify(buf)
  if cb_state then cb_state(buf, STATE[kind](n)) end
end

local function schedule_settle(buf, ms)
  local o = obs[buf]
  if not o then return end
  stop_timer(buf)
  o.timer = vim.defer_fn(function()
    if obs[buf] then obs[buf].timer = nil end
    settle(buf)
  end, ms)
end

--- File event: only establish that an edit happened (cheap stat), mark it,
--- and classify once the file has been quiet for SETTLE_MS.
local function on_event(buf)
  if writing[buf] then return end
  local fp = fingerprint(vim.api.nvim_buf_get_name(buf))
  if fp and fp_eq(fp, own_fp[buf]) then return end -- our own write
  if cb_state then cb_state(buf, { kind = "external" }) end
  schedule_settle(buf, M.SETTLE_MS)
end

---------------------------------------------------------------------------
-- auto modes (load = "auto" / "on_focus"): unchanged semantics
---------------------------------------------------------------------------

--- Save `buf`, folding in auto-resolvable external changes (chained). Used by
--- the auto load modes only; manual saves go through agent-merge.app.
--- @param hooks? { if_changed?: fun():boolean, if_conflict?: fun(n:integer):boolean }
--- @return boolean saved
function M.try_save(buf, hooks)
  hooks = hooks or {}
  local path = vim.api.nvim_buf_get_name(buf)

  for _ = 1, MAX_ROUNDS do
    local mine = buf_lines(buf)
    local disk = M.read_disk(buf, path)
    local base = bases[buf] or disk or {}

    if disk == nil then
      local proceed = hooks.if_conflict and hooks.if_conflict(0) or false
      if not proceed then return false end
      if M.write_if(buf, false) then return true end
    elseif eq(disk, base) then
      if M.write_if(buf, disk) then return true end
    else
      local merged, n = merge.three_way(mine, base, disk)
      if n < 0 then return false end
      local proceed
      if n == 0 then
        proceed = (hooks.if_changed == nil) or hooks.if_changed()
      else
        proceed = hooks.if_conflict and hooks.if_conflict(n) or false
      end
      if not proceed then return false end
      if n == 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
      end
      bases[buf] = disk -- buffer is now derived from `disk`; loop writes it
    end
  end
  return false
end

function M.auto_merge(buf)
  return M.try_save(buf)
end

---------------------------------------------------------------------------
-- observation
---------------------------------------------------------------------------

--- Start observing a buffer and classify its current state right away (it
--- may be stale after being unfocused).
--- @param opts? { poll_ms?: integer }
--- @return boolean started
function M.observe(buf, opts)
  M.unobserve(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local handle = watch.watch(path, function()
    if vim.api.nvim_buf_is_valid(buf) and obs[buf] then on_event(buf) end
  end, opts)
  if not handle then return false end
  obs[buf] = { handle = handle }
  schedule_settle(buf, 0)
  return true
end

function M.unobserve(buf)
  local o = obs[buf]
  if o then
    stop_timer(buf)
    watch.unwatch(o.handle)
    obs[buf] = nil
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

--- Register the state callback: fn(buf, state) with state =
---   nil                         disk matches base (in sync)
---   { kind = "external" }       something changed; not classified yet
---   { kind = "change" }         auto-mergeable external change
---   { kind = "conflict", n }    conflicting external change
---   { kind = "deleted" }        file removed externally
function M.on_state(fn)
  cb_state = fn
end

--- Register the callback fired when a buffer returns to sync (new base).
function M.on_sync(fn)
  cb_sync = fn
end

return M
