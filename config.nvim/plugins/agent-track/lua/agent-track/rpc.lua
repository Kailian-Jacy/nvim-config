local git = require("agent-track.git")
local M = {}
local function pick(a, idx, ...)
  if type(a) ~= "table" then return nil end
  for i = 1, select("#", ...) do local v = a[select(i, ...)]; if v ~= nil then return v end end
  return idx and a[idx] or nil
end
local function msg_of(a, idx) return pick(a, idx, "comment", "reason", "message") end
local function tgt_of(a) return pick(a, 1, "target", "sha", "index") end
local H = {
  ping = function() local i = git.root_info(); return { ok = true, pid = vim.fn.getpid(), cwd = vim.fn.getcwd(), git_root = i and i.root or nil } end,
  init = function(t, a) return t.init_session(pick(a, 1, "remote"), { session = a.session, base = a.base }) end,
  attach = function(t, a) return t.attach(pick(a, 1, "remote", "url", "repo"), { session = a.session, base = a.base }) end,
  detach = function(t, a) return t.detach(pick(a, 1, "session")) end,
  fetch = function(t, a) return t.fetch(pick(a, 1, "session"), { async = false }) end,
  status = function(t, a) return t.status(pick(a, 1, "session")) end,
  list = function(t, a) return t.list(pick(a, 1, "session"), type(a[2]) == "table" and a[2] or { preview_conflicts = a.preview_conflicts }) end,
  review = function(t, a) return t.review(tgt_of(a), pick(a, 2, "status"), type(a[3]) == "table" and a[3] or { comment = msg_of(a), prefix = a.prefix, session = a.session }) end,
  approve = function(t, a) return t.review(tgt_of(a), "approved", { comment = msg_of(a), prefix = a.prefix, session = a.session }) end,
  reject = function(t, a) return t.review(tgt_of(a), "rejected", { comment = msg_of(a, 2), session = a.session }) end,
  apply = function(t, a) return t.apply(pick(a, 1, "target"), type(a[2]) == "table" and a[2] or { mode = a.mode, session = a.session }) end,
  undo = function(t, a) return t.undo(pick(a, 1, "session")) end,
  clean = function(t, a) return t.clean(pick(a, 1, "session"), { remote = a.remote }) end,
  open = function(_, a) return require("agent-track.reviewer").open(tgt_of(a), { session = a.session }) end,
  panel = function(_, a) return require("agent-track.reviewer").panel({ session = pick(a, 1, "session") }) end,
  close = function() return require("agent-track.reviewer").close() end,
}
H.info, H.init_session, H.sync = H.ping, H.init, H.apply
function M.dispatch(req)
  local ok_d, p = true, req
  if type(req) == "string" then ok_d, p = pcall(vim.json.decode, req) end
  if not ok_d or type(p) ~= "table" then return vim.json.encode({ ok = false, error = "invalid JSON request" }) end
  local fn = H[p.method]
  if not fn then return vim.json.encode({ ok = false, error = "unknown rpc method: " .. tostring(p.method) }) end
  local ok, res = pcall(fn, require("agent-track"), type(p.args) == "table" and p.args or {})
  if not ok then return vim.json.encode({ ok = false, error = tostring(res) }) end
  if type(res) == "table" and res.ok == false then return vim.json.encode({ ok = false, error = res.error or "operation failed", result = res }) end
  return vim.json.encode({ ok = true, result = res })
end
return M
