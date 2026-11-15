local config = require("agent-track.config")
local git = require("agent-track.git")
local M, watchers, augroup_ready = {}, {}, false

function M.parse_ssh_remote(r)
  if type(r) ~= "string" or r == "" then return nil end
  local h, port, p = r:match("^ssh://([^/:]+):(%d+)(/.*)$")
  if h then return { host = h, port = port, path = (p:gsub("^/~/", "~/")) } end
  h, p = r:match("^ssh://([^/]+)(/.*)$")
  if h then return { host = h, path = (p:gsub("^/~/", "~/")) } end
  if r:match("^[/%.~]") or r:match("^%a:[/\\]") or r:match("^[%w+.-]+://") then return nil end
  h, p = r:match("^([^/\\:%s]+):(.+)$"); return h and { host = h, path = p } or nil
end
function M.is_ssh_remote(r) return M.parse_ssh_remote(r) ~= nil end

local function close_h(h) if h and not h:is_closing() then pcall(h.stop, h); pcall(h.close, h) end end
local function deepest_dir(dir)
  while dir and dir ~= "" and dir ~= "/" do
    local st = vim.uv.fs_stat(dir); if st and st.type == "directory" then return dir end
    local p = vim.fn.fnamemodify(dir, ":h"); if p == dir then break end; dir = p
  end
end
local function build_tail_argv(remote, session, cfg)
  local custom = cfg.watch and cfg.watch.remote_tail_cmd
  if type(custom) == "function" then custom = custom(remote, session) end
  if type(custom) == "table" then return git.resolve_bin(vim.deepcopy(custom)) end
  if type(custom) == "string" and custom ~= "" then return git.resolve_bin({ "sh", "-c", custom }) end
  local parsed = M.parse_ssh_remote(remote); if not parsed then return nil end
  local sq, ref_rel = parsed.path:gsub("'", "'\\''"), config.ref(session, "agent")
  local argv = vim.deepcopy(cfg.ssh_cmd or { "ssh", "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15" })
  if parsed.port then vim.list_extend(argv, { "-p", tostring(parsed.port) }) end
  return git.resolve_bin(vim.list_extend(argv, { parsed.host, string.format("tail -n0 -F '%s/.git/logs/%s' 2>/dev/null || tail -n0 -F '%s/logs/%s'", sq, ref_rel, sq, ref_rel) }))
end

function M.detach(session)
  local w = watchers[config.resolve_session(session)]; if not w then return false end
  w.stopped, watchers[w.session] = true, nil
  for _, k in ipairs({ "fse", "debounce_timer", "poll_timer", "reconnect_timer" }) do close_h(w[k]) end
  if w.proc then pcall(function() w.proc:kill(9) end) end; return true
end
function M.detach_all() for _, s in ipairs(vim.tbl_keys(watchers)) do M.detach(s) end end

function M.attach(session, remote, on_change)
  local cfg, s = config.get(), config.resolve_session(session)
  local wcfg = cfg.watch or {}; M.detach(s)
  if wcfg.enabled == false or not remote or remote == "" then return { ok = true, active = false, mode = "disabled" } end
  if not augroup_ready then augroup_ready = true; vim.api.nvim_create_autocmd("VimLeavePre", { group = vim.api.nvim_create_augroup("AgentTrackWatchCleanup", { clear = true }), callback = M.detach_all }) end
  local m = wcfg.mode or "auto"
  local mode = (m == "ssh" or wcfg.remote_tail_cmd ~= nil) and "ssh" or ((m == "local" or m == "poll") and m or (M.is_ssh_remote(remote) and "ssh" or "local"))
  local debounce_ms, poll_ms, reconnect_ms = tonumber(wcfg.debounce_ms) or 150, tonumber(wcfg.poll_ms) or 5000, tonumber(wcfg.reconnect_ms) or 3000
  local w = { session = s, remote = remote, mode = mode, stopped = false, debounce_timer = vim.uv.new_timer() }; watchers[s] = w
  local function trigger() if not w.stopped and not w.debounce_timer:is_closing() then w.debounce_timer:stop(); w.debounce_timer:start(debounce_ms, 0, vim.schedule_wrap(function() if not w.stopped then on_change() end end)) end end
  if mode == "local" then
    local exp = vim.fn.expand(remote); local rinfo = git.root_info(exp)
    local target_dir = (rinfo and rinfo.common_dir or (exp .. "/.git")) .. "/logs/" .. vim.fn.fnamemodify(config.ref(s, "agent"), ":h")
    local function arm(force)
      local dir = not w.stopped and deepest_dir(target_dir) or nil; if not dir or (not force and w.watched_dir == dir) then return end
      close_h(w.fse); w.fse, w.watched_dir = vim.uv.new_fs_event(), dir
      local cb = vim.schedule_wrap(function(err) if not w.stopped and not err then if w.watched_dir ~= target_dir then arm(false) end; trigger() end end)
      if w.fse:start(dir, { recursive = true }, cb) == nil then w.fse:stop(); w.fse:start(dir, {}, cb) end
    end
    arm(true)
  elseif mode == "ssh" then
    local function start_stream()
      local argv = not w.stopped and build_tail_argv(remote, s, cfg) or nil; if not argv then return end
      w.proc = vim.system(argv, { text = true, stdin = false, stderr = false, stdout = function(e, d) if not e and d and d ~= "" then vim.schedule(trigger) end end }, vim.schedule_wrap(function()
        w.proc = nil; if w.stopped then return end
        close_h(w.reconnect_timer); w.reconnect_timer = vim.uv.new_timer(); w.reconnect_timer:start(reconnect_ms, 0, vim.schedule_wrap(function() if not w.stopped then on_change(); start_stream() end end))
      end))
    end
    start_stream()
  end
  if poll_ms > 0 then w.poll_timer = vim.uv.new_timer(); w.poll_timer:start(poll_ms, poll_ms, vim.schedule_wrap(function() if not w.stopped then on_change() end end)) end
  return { ok = true, active = true, session = s, remote = remote, mode = mode }
end

function M.status(session)
  local s = config.resolve_session(session); local w = watchers[s]
  return (w and not w.stopped) and { active = true, session = s, remote = w.remote, mode = w.mode } or { active = false, session = s }
end
return M
