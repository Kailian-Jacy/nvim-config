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
function M.build_tail_argv(remote, session, cfg)
  cfg = cfg or config.get()
  local custom = cfg.watch and cfg.watch.remote_tail_cmd
  if type(custom) == "function" then custom = custom(remote, session) end
  if type(custom) == "table" then return git.resolve_bin(vim.deepcopy(custom)) end
  if type(custom) == "string" and custom ~= "" then return git.resolve_bin({ "sh", "-c", custom }) end
  local parsed = M.parse_ssh_remote(remote); if not parsed then return nil end
  local sq = parsed.path:gsub("'", "'\\''")
  -- watch only the connected session: its agent ref and its notes ref (other sessions' activity is ignored)
  local ses = config.resolve_session(session):gsub("'", "'\\''")
  local rp = ((cfg.ref_prefix or "refs/subcommits"):gsub("/+$", "") .. "/" .. ses):gsub("'", "'\\''")
  local np = ((cfg.notes_prefix or "subcommits"):gsub("^refs/notes/", ""):gsub("/+$", "") .. "/" .. ses):gsub("'", "'\\''")
  local argv = vim.deepcopy(cfg.ssh_cmd or config.get().ssh_cmd)
  if parsed.port then vim.list_extend(argv, { "-p", tostring(parsed.port) }) end
  local cd_arg = parsed.path == "~" and '"$HOME"' or (parsed.path:sub(1, 2) == "~/" and ('"$HOME"\'' .. parsed.path:sub(2):gsub("'", "'\\''") .. "'") or ("'" .. sq .. "'"))
  return git.resolve_bin(vim.list_extend(argv, { parsed.host, string.format("cd %s && q() { git for-each-ref --format='%%(refname)=%%(objectname)' '%s/agent' 'refs/notes/%s' 2>/dev/null; }; prev=$(q) && while :; do sleep 2; cur=$(q); if [ \"$cur\" != \"$prev\" ]; then printf 'changed\\n'; prev=\"$cur\"; fi; done", cd_arg, rp, np) }))
end

function M.detach(session)
  local keys = session and { config.resolve_session(session) } or vim.tbl_keys(watchers)
  local had = false
  for _, k in ipairs(keys) do
    local w = watchers[k]
    if w then
      had, w.stopped, watchers[k] = true, true, nil
      for _, tk in ipairs({ "fse", "fse_notes", "debounce_timer", "poll_timer", "reconnect_timer" }) do close_h(w[tk]) end
      if w.proc then pcall(function() w.proc:kill(9) end) end
    end
  end
  return had
end
function M.detach_all() M.detach(nil) end

--- A configured git remote name (e.g. `hg`) -> its URL, so the mode check and ssh/local watching see the real
--- location instead of treating the bare name as a local path (which silently watched nothing).
function M.resolve_url(remote, root)
  if type(remote) ~= "string" or remote == "" or remote:find("[/:]") then return remote end
  local r = git.run(root, { "remote", "get-url", remote }, { ident = false })
  local url = r.ok and vim.trim(r.stdout) or ""
  return url ~= "" and url or remote
end
function M.attach(session, remote, on_change, root)
  remote = M.resolve_url(remote, root)
  local cfg, s = config.get(), config.resolve_session(session)
  local wcfg = cfg.watch or {}; M.detach(s)
  for oses, ow in pairs(watchers) do if ow.remote == remote then M.detach(oses) end end
  if wcfg.enabled == false or not remote or remote == "" then return { ok = true, active = false, mode = "disabled" } end
  if not augroup_ready then augroup_ready = true; vim.api.nvim_create_autocmd("VimLeavePre", { group = vim.api.nvim_create_augroup("AgentTrackWatchCleanup", { clear = true }), callback = M.detach_all }) end
  local m = wcfg.mode or "auto"
  local mode = (m == "ssh" or wcfg.remote_tail_cmd ~= nil) and "ssh" or ((m == "local" or m == "poll") and m or (M.is_ssh_remote(remote) and "ssh" or "local"))
  local debounce_ms, poll_ms, reconnect_ms = tonumber(wcfg.debounce_ms) or 150, tonumber(wcfg.poll_ms) or 5000, tonumber(wcfg.reconnect_ms) or 3000
  local eff_poll = (mode == "ssh") and (tonumber(wcfg.ssh_poll_ms) or 0) or poll_ms
  local w = { session = s, remote = remote, mode = mode, stopped = false, failures = 0, debounce_timer = vim.uv.new_timer() }; watchers[s] = w
  local function trigger() if not w.stopped and not w.debounce_timer:is_closing() then w.debounce_timer:stop(); w.debounce_timer:start(debounce_ms, 0, vim.schedule_wrap(function() if not w.stopped then on_change() end end)) end end
  if mode == "local" then
    local exp = vim.fn.expand(remote); local rinfo = git.root_info(exp)
    local target_dir = (rinfo and rinfo.common_dir or (exp .. "/.git")) .. "/logs/" .. (cfg.ref_prefix or "refs/subcommits"):gsub("/+$", "") .. "/" .. s -- this session only
    local function arm(force)
      local dir = not w.stopped and deepest_dir(target_dir) or nil; if not dir or (not force and w.watched_dir == dir) then return end
      close_h(w.fse); w.fse, w.watched_dir = vim.uv.new_fs_event(), dir
      local cb = vim.schedule_wrap(function(err) if not w.stopped and not err then if w.watched_dir ~= target_dir then arm(false) end; trigger() end end)
      if w.fse:start(dir, { recursive = true }, cb) == nil then w.fse:stop(); w.fse:start(dir, {}, cb) end
    end
    arm(true)
    -- review notes (comments from the other side) log under logs/refs/notes/<np>/<S>, outside the subcommit dir
    local np = (cfg.notes_prefix or "subcommits"):gsub("^refs/notes/", ""):gsub("/+$", "")
    local notes_dir = (rinfo and rinfo.common_dir or (exp .. "/.git")) .. "/logs/refs/notes/" .. np
    if vim.fn.isdirectory(notes_dir) == 0 then vim.fn.mkdir(notes_dir, "p") end
    w.fse_notes = vim.uv.new_fs_event()
    w.fse_notes:start(notes_dir, {}, vim.schedule_wrap(function(err, fname) if not w.stopped and not err and (fname == nil or fname == s) then trigger() end end))
  elseif mode == "ssh" then
    local function start_stream()
      local argv = not w.stopped and M.build_tail_argv(remote, s, cfg) or nil; if not argv then return end
      local started = vim.uv.now()
      local ok, proc = pcall(vim.system, argv, { text = true, stdin = false, stderr = false, stdout = function(e, d) if not e and d and d ~= "" then vim.schedule(trigger) end end }, vim.schedule_wrap(function()
        w.proc = nil; if w.stopped then return end
        close_h(w.reconnect_timer)
        if vim.uv.now() - started >= 15000 then
          w.failures = 0
          w.reconnect_timer = vim.uv.new_timer()
          w.reconnect_timer:start(reconnect_ms, 0, vim.schedule_wrap(function() if not w.stopped then on_change(); start_stream() end end))
        else
          w.failures = w.failures + 1
          if w.failures >= (tonumber(wcfg.max_retries) or 3) then
            M.detach(s)
            vim.notify("agent-track: SSH watcher failed repeatedly and was stopped (:AgentTrack attach to retry)", vim.log.levels.ERROR)
            return
          end
          w.reconnect_timer = vim.uv.new_timer()
          w.reconnect_timer:start(reconnect_ms * (2 ^ w.failures), 0, vim.schedule_wrap(function() if not w.stopped then start_stream() end end))
        end
      end))
      if ok then w.proc = proc else M.detach(s); vim.notify("agent-track: SSH watcher failed repeatedly and was stopped (:AgentTrack attach to retry)", vim.log.levels.ERROR) end
    end
    start_stream()
  end
  if eff_poll > 0 then w.poll_timer = vim.uv.new_timer(); w.poll_timer:start(eff_poll, eff_poll, vim.schedule_wrap(function() if not w.stopped then on_change() end end)) end
  return { ok = true, active = not w.stopped, session = s, remote = remote, mode = mode }
end

function M.status(session)
  local s = config.resolve_session(session); local w = watchers[s]
  if not w and not session then for _, v in pairs(watchers) do if not v.stopped then w = v; break end end end
  return (w and not w.stopped) and { active = true, session = s, remote = w.remote, mode = w.mode, poll = w.poll_timer ~= nil, failures = w.failures or 0 } or { active = false, session = s }
end
return M
