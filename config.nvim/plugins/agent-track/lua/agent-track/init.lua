local config = require("agent-track.config")
local git = require("agent-track.git")
local sync = require("agent-track.sync")
local watch = require("agent-track.watch")
local M = { rpc = require("agent-track.rpc") }
local sl_cache, fetch_inflight, fetch_queued, cmd_registered = "", {}, {}, false

local function ctx_of(s, opts)
  local o, ses = type(s) == "table" and s or (opts or {}), config.resolve_session(type(s) == "table" and s.session or s)
  local info, err = git.root_info(o.cwd); return ses, o, info, err
end
local function emit(pattern, hook_key, data)
  local hooks = config.get().hooks; if hooks and type(hooks[hook_key]) == "function" then pcall(hooks[hook_key], data) end
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = pattern, modeline = false, data = data })
end
local function ensure_base(root, s, remote, explicit_base, reset)
  local base_ref, synced_ref = config.ref(s, "base"), config.ref(s, "synced")
  local base = explicit_base and git.rev_parse(root, explicit_base) or (not reset and git.rev_parse(root, base_ref)) or nil
  if not base and remote and remote ~= "" then git.run(root, { "fetch", remote, "+" .. base_ref .. ":" .. base_ref }, { reflog = true }); base = git.rev_parse(root, base_ref) end
  base = base or git.rev_parse(root, "HEAD"); if not base then return nil end
  git.update_ref(root, base_ref, base, "init session base")
  if reset or not git.rev_parse(root, synced_ref) then git.update_ref(root, synced_ref, base, "init synced") end
  return base
end
local function update_statusline(res)
  local cfg = config.get()
  if not cfg.statusline or cfg.statusline.enabled == false or not res or not res.ok then sl_cache = ""; return end
  local c = res.counts; local pend = c.pending + c.stale
  if c.total == 0 and not res.remote then sl_cache = ""; return end
  if type(cfg.statusline.format) == "function" then
    local ok, out = pcall(cfg.statusline.format, { session = res.session, remote = res.remote, total = c.total, synced = c.synced, pending = pend })
    sl_cache = ok and tostring(out or "") or ""; return
  end
  if c.total == 0 then sl_cache = string.format("[track:%s idle]", res.session); return end
  sl_cache = string.format("[track %d/%d%s]", c.synced, c.total, pend > 0 and (" ·" .. pend) or "")
end
function M.get_config() return config.get() end
function M.attach(remote, opts) return M.init_session(remote, vim.tbl_extend("force", {}, opts or {}, { remote = remote })) end
function M.detach(session) local s = config.resolve_session(session); watch.detach(s); return { ok = true, session = s, active = false } end
function M.statusline() local cfg = config.get(); return (cfg.statusline and cfg.statusline.enabled ~= false) and (sl_cache or "") or "" end
function M.init_session(remote_or_opts, maybe_opts)
  local opts = type(remote_or_opts) == "table" and remote_or_opts or (maybe_opts or {})
  local remote = type(remote_or_opts) == "table" and opts.remote or remote_or_opts
  local s, _, info, err = ctx_of(opts.session, opts); if not info then return { ok = false, error = err } end
  local base_ref, r_head, r_base = config.ref(s, "base"), nil, nil
  if remote and remote ~= "" then
    local lr = git.run(info.root, { "ls-remote", remote, "HEAD", base_ref }, { ident = false })
    if not lr.ok then local e = vim.trim(lr.stderr ~= "" and lr.stderr or ("cannot reach remote: " .. remote)); vim.notify("agent-track: " .. e, vim.log.levels.ERROR); return { ok = false, error = e } end
    for line in (lr.stdout or ""):gmatch("[^\n]+") do
      local sha, ref = line:match("^(%x+)%s+(%S+)$"); if ref == "HEAD" then r_head = sha elseif ref == base_ref then r_base = sha end
    end
    if (r_base or r_head) and not ((r_base and git.rev_parse(info.root, r_base .. "^{commit}")) or (r_head and git.rev_parse(info.root, r_head .. "^{commit}"))) then
      local e = "remote does not share git history with current cwd repo (" .. info.root .. ")"
      vim.notify("agent-track: " .. e, vim.log.levels.ERROR); return { ok = false, error = e }
    end
  end
  config.set_active_session(s)
  local base = ensure_base(info.root, s, r_base and remote or nil, opts.base or (r_base and git.rev_parse(info.root, r_base .. "^{commit}")), opts.reset)
  if not base then return { ok = false, error = "cannot resolve base commit" } end
  if remote and remote ~= "" and not r_base then git.push_refs(info.root, remote, { base_ref }) end
  local state = git.read_state(info.root, s); if opts.reset then state.applied_ids = {} end
  if remote and remote ~= "" then state.remote = remote end; git.write_state(info.root, s, state)
  if state.remote and state.remote ~= "" then
    M.fetch(s, { async = false, silent = true })
    if opts.watch ~= false then watch.attach(s, state.remote, function() M.fetch(s, { async = true, silent = true }) end) end
  end
  M.list(s); return { ok = true, session = s, remote = state.remote, base = base }
end
function M.fetch(session, opts)
  local s, o, info, err = ctx_of(session, opts); if not info then return { ok = false, error = err } end
  local remote = o.remote or git.read_state(info.root, s).remote; if not remote or remote == "" then return { ok = false, error = "no remote configured for session " .. s } end
  ensure_base(info.root, s, remote)
  local cfg, agent_ref = config.get(), config.ref(s, "agent")
  local np, old_agent = (cfg.notes_prefix or "subcommits"):gsub("^refs/notes/", ""):gsub("/+$", ""), git.rev_parse(info.root, agent_ref)
  local fargs = { "fetch", remote, "+" .. agent_ref .. ":" .. agent_ref, "+refs/notes/" .. np .. "/*:refs/notes/" .. np .. "/*" }
  local function done(r)
    local new_agent = git.rev_parse(info.root, agent_ref); local changed, lres = (new_agent ~= nil and new_agent ~= old_agent), M.list(s)
    if changed then
      if cfg.notify_on_arrival then vim.notify(string.format("agent-track [%s]: %d subcommits", s, #(lres.items or {})), vim.log.levels.INFO) end
      emit("AgentTrackUpdated", "on_updated", { session = s, agent = new_agent, previous = old_agent })
      if cfg.auto_sync_approved then M.apply("approved", { session = s }) end
    end
    return (not r.ok and not o.silent and not new_agent) and { ok = false, error = vim.trim(r.stderr) } or { ok = true, session = s, agent = new_agent, updated = changed, items = lres.items, counts = lres.counts }
  end
  if not o.async then return done(git.run(info.root, fargs, { reflog = true })) end
  if fetch_inflight[s] then fetch_queued[s] = true; return { ok = true, async = true, queued = true } end; fetch_inflight[s] = true
  git.run_async(info.root, fargs, { reflog = true }, function(r) fetch_inflight[s] = nil; done(r); if fetch_queued[s] then fetch_queued[s] = nil; M.fetch(s, o) end end)
  return { ok = true, async = true }
end

function M.list(session, opts)
  local s, o, info, err = ctx_of(session, opts); if not info then return { ok = false, error = err, items = {} } end
  local base, agent = git.rev_parse(info.root, config.ref(s, "base")), git.rev_parse(info.root, config.ref(s, "agent"))
  local synced, approved_prefix = git.rev_parse(info.root, config.ref(s, "synced")) or base, git.rev_parse(info.root, config.ref(s, "approved"))
  local state, notes_arg = git.read_state(info.root, s), config.notes_arg(s)
  local items = (base and agent) and git.log_subcommits(info.root, base, agent, notes_arg) or {}
  local prefix_idx, need_rw, notes_by_id, pids = 0, {}, {}, {}
  for i, it in ipairs(items) do
    if approved_prefix and it.sha == approved_prefix then prefix_idx = i end
    if not it.direct_note and it.subcommit_id then need_rw[#need_rw + 1] = it.sha end
  end
  if #need_rw > 0 then notes_by_id = git.notes_by_subcommit_id(info.root, notes_arg); if next(notes_by_id) then pids = git.patch_ids(info.root, need_rw) end end
  local is_synced, counts = sync.synced_lookup(info.root, base, synced, state), { total = #items, synced = 0, approved = 0, rejected = 0, pending = 0, stale = 0 }
  for i, it in ipairs(items) do
    local st, via, cm = "pending", "none", ""
    if it.direct_note then st = it.direct_note.status or "pending"; via, cm = (st == "pending" and "none" or "note"), it.direct_note.comment or ""
    elseif it.subcommit_id and notes_by_id[it.subcommit_id] then
      local n = notes_by_id[it.subcommit_id]
      if n.patch_id and n.patch_id == (pids[it.sha] or "") then st = n.status or "pending"; via, cm = (st == "pending" and "none" or "note"), n.comment or ""
      elseif n.status == "approved" then st, via, cm = "stale", "note", n.comment or "" end
    end
    if st == "pending" and via == "none" and not it.direct_note and approved_prefix and ((prefix_idx > 0 and i <= prefix_idx) or (prefix_idx == 0 and git.is_ancestor(info.root, it.sha, approved_prefix))) then st, via = "approved", "prefix" end
    it.review_status, it.review_via, it.comment, it.direct_note, it.synced, it.would_conflict = st, via, cm, nil, is_synced(it), false
    if it.synced then counts.synced = counts.synced + 1 end; counts[st] = (counts[st] or 0) + 1
  end
  if o.preview_conflicts and #items > 0 then local pmap = sync.preview_conflicts(info, base, synced, items); for _, it in ipairs(items) do it.would_conflict = pmap[it.sha] == true end end
  local out = { ok = true, session = s, remote = state.remote, base = base, synced = synced, approved_prefix = approved_prefix, items = items, counts = counts }
  update_statusline(out); return out
end

function M.review(sha_or_idx, status, opts)
  opts = opts or {}
  if not ({ approved = true, rejected = true, pending = true })[status] then return { ok = false, error = "invalid review status: " .. tostring(status) } end
  local s, _, info, err = ctx_of(opts.session, opts); if not info then return { ok = false, error = err } end
  local lres = M.list(s); if not lres.ok or #(lres.items or {}) == 0 then return { ok = false, error = lres.error or "no subcommits to review" } end
  local items = lres.items
  local it = git.find_item(items, sha_or_idx) or ((sha_or_idx == nil or sha_or_idx == "") and (opts.prefix and items[#items] or vim.iter(items):find(function(c) return c.review_status == "pending" or c.review_status == "stale" end) or items[#items]) or nil)
  if not it then return { ok = false, error = "subcommit not found: " .. tostring(sha_or_idx) } end
  local approved_ref, notes_arg, notes_ref = config.ref(s, "approved"), config.notes_arg(s), config.notes_ref(s)
  local function write_note(cm)
    return git.run(info.root, { "notes", "--ref=" .. notes_arg, "add", "-f", "-m", vim.json.encode({ status = status, comment = cm or "", subcommit_id = it.subcommit_id or "", patch_id = git.patch_ids(info.root, { it.sha })[it.sha] or "", updated_at = os.time() }), it.sha })
  end
  if opts.prefix and status == "approved" then git.update_ref(info.root, approved_ref, it.sha, "approve prefix"); if opts.comment and opts.comment ~= "" then write_note(opts.comment) end
  else local nr = write_note(opts.comment); if not nr.ok then return { ok = false, error = vim.trim(nr.stderr) } end end
  local pushed = (opts.push ~= false) and (git.push_refs(info.root, lres.remote, { notes_ref, approved_ref })) or false
  M.list(s); emit("AgentTrackReviewed", "on_reviewed", { session = s, sha = it.sha, status = status, prefix = opts.prefix == true })
  if config.get().auto_sync_approved and status == "approved" then M.apply("approved", { session = s }) end
  return { ok = true, session = s, sha = it.sha, status = status, prefix = opts.prefix == true, pushed = pushed }
end

function M.apply(target, opts)
  if type(target) == "table" then opts, target = target, target.target end
  local s, o, info, err = ctx_of(opts and opts.session, opts); if not info then return { ok = false, error = err } end
  local lres = M.list(s); if not lres.ok then return lres end
  local res = sync.apply(info, s, lres.items or {}, target, o); M.list(s)
  if res.ok and not res.noop then emit("AgentTrackSynced", "on_synced", { session = s, synced = res.synced, clean = true }) end
  return res
end
function M.undo(session, opts)
  local s, _, info, err = ctx_of(session, opts); if not info then return { ok = false, error = err } end
  local res = sync.undo(info, s); M.list(s); if res.ok then emit("AgentTrackSynced", "on_synced", { session = s, undo = true, synced = res.restored_synced }) end; return res
end
function M.clean(session, opts)
  local s, _, info, err = ctx_of(session, opts); watch.detach(s); if not info then return { ok = false, error = err } end
  for _, name in ipairs({ "base", "agent", "synced", "approved", "undo", "state" }) do git.delete_ref(info.root, config.ref(s, name)) end
  git.delete_ref(info.root, config.notes_ref(s)); sl_cache = ""; return { ok = true, session = s, cleaned = true }
end
function M.status(session)
  local lres = M.list(config.resolve_session(session)); if not lres.ok then return lres end
  return { ok = true, session = lres.session, remote = lres.remote, base = lres.base, synced = lres.synced, approved_prefix = lres.approved_prefix, counts = lres.counts, watcher = watch.status(lres.session) }
end

local CMD = {
  init = function(f) M.init_session(f[2]) end, detach = function(f) M.detach(f[2]) end, fetch = function(f) M.fetch(f[2]) end,
  attach = function(f) if f[2] then M.attach(f[2], { session = f[3] }) else vim.notify("Usage: :AgentTrack attach <remote> [session]", vim.log.levels.ERROR) end end,
  status = function(f)
    local st = M.status(f[2]); if not st.ok then return vim.notify("agent-track: " .. tostring(st.error), vim.log.levels.WARN) end; local c = st.counts
    vim.notify(string.format("agent-track [%s] remote=%s synced=%d/%d ✓%d ·%d ✗%d watch=%s", st.session, st.remote or "-", c.synced, c.total, c.approved, c.pending + c.stale, c.rejected, st.watcher.active and st.watcher.mode or "off"))
  end,
  list = function(f) require("agent-track.reviewer").panel({ session = f[2] }) end, open = function(f) require("agent-track.reviewer").open(f[2]) end,
  approve = function(f) M.review(f[2] ~= "--prefix" and f[2] or nil, "approved", { prefix = (f[2] == "--prefix" or f[3] == "--prefix") }) end,
  reject = function(f) M.review(f[2], "rejected", { comment = table.concat(vim.list_slice(f, 3), " ") }) end,
  sync = function(f) M.apply(f[2] or "approved") end, undo = function(f) M.undo(f[2]) end, clean = function(f) M.clean(f[2]) end,
}
CMD.review = CMD.list; local SUB = vim.tbl_keys(CMD); table.sort(SUB)
local function register_commands()
  if cmd_registered then return end; cmd_registered = true
  vim.api.nvim_create_user_command("AgentTrack", function(c) local sub = c.fargs[1] or "status"; if CMD[sub] then CMD[sub](c.fargs) else vim.notify("Unknown :AgentTrack subcommand: " .. sub, vim.log.levels.ERROR) end end, {
    nargs = "*", desc = "AgentTrack subcommit workflow commands",
    complete = function(lead, line)
      local p = vim.split(line, "%s+", { trimempty = true })
      local opts = (#p <= 1 or (#p == 2 and line:sub(-1) ~= " ")) and SUB or (p[2] == "sync" and { "approved", "all" } or {})
      return vim.tbl_filter(function(s) return s:find(lead, 1, true) == 1 end, opts)
    end,
  })
end
function M.setup(opts) config.setup(opts); register_commands(); return M end
register_commands(); return M
