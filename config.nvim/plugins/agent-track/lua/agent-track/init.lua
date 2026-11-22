local config = require("agent-track.config")
local git = require("agent-track.git")
local sync = require("agent-track.sync")
local watch = require("agent-track.watch")
local M = { rpc = require("agent-track.rpc") }
local sl_cache, fetch_inflight, fetch_queued, push_inflight, push_queued, cmd_registered = "", {}, {}, {}, {}, false

local function ctx_of(s, opts)
  local o, ses = type(s) == "table" and s or (opts or {}), config.resolve_session(type(s) == "table" and s.session or s)
  local info, err = git.root_info(o.cwd); return ses, o, info, err
end
local function emit(pattern, hook_key, data)
  local hooks = config.get().hooks; if hooks and type(hooks[hook_key]) == "function" then pcall(hooks[hook_key], data) end
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = pattern, modeline = false, data = data })
end
local function ref_prefix() return (config.get().ref_prefix or "refs/subcommits"):gsub("/+$", "") end
local function repo_remote(root, s)
  local r = s and git.read_state(root, s).remote or nil; if r and r ~= "" then return r end
  local cr = git.run(root, { "config", "--get", "agent-track.remote" }, { ident = false })
  local v = cr.ok and vim.trim(cr.stdout) or ""; return v ~= "" and v or nil
end
local function discover_sessions(root)
  local rp = ref_prefix()
  local r, out, heads = git.run(root, { "for-each-ref", "--sort=-committerdate", "--format=%(refname)\t%(objectname)", rp .. "/*/agent" }, { ident = false }), {}, {}
  local pat = "^" .. vim.pesc(rp) .. "/([^/]+)/agent$"
  for line in (r.ok and r.stdout or ""):gmatch("[^\n]+") do
    local ref, sha = line:match("^(%S+)\t(%x+)$"); local ses = ref and ref:match(pat)
    if ses then out[#out + 1], heads[ses] = ses, sha end
  end
  return out, heads
end
local function merge_base(root, a, b)
  local r = (a and b) and git.run(root, { "merge-base", a, b }, { ident = false }) or nil
  local sha = (r and r.ok) and vim.trim(r.stdout) or ""; return sha ~= "" and sha or nil
end
local function has_subcommits(root, ses, agent_sha)
  local a = agent_sha or git.rev_parse(root, config.ref(ses, "agent")); if not a then return false end
  local b = git.rev_parse(root, config.ref(ses, "base"))
  if not b then local h = git.rev_parse(root, "HEAD"); b = (h and merge_base(root, h, a)) or h end
  return b ~= nil and b ~= a
end
local function ensure_base(root, s, remote, explicit_base, reset)
  local base_ref, synced_ref = config.ref(s, "base"), config.ref(s, "synced")
  local prev_base = git.rev_parse(root, base_ref)
  local base = explicit_base and git.rev_parse(root, explicit_base) or (not reset and prev_base) or nil
  if not base and remote and remote ~= "" then git.run(root, { "fetch", remote, "+" .. base_ref .. ":" .. base_ref }, { reflog = true }); base = git.rev_parse(root, base_ref) end
  if not base then
    local h, a = git.rev_parse(root, "HEAD"), git.rev_parse(root, config.ref(s, "agent"))
    base = (h and a and merge_base(root, h, a)) or h
  end
  if not base then return nil end
  git.update_ref(root, base_ref, base, "init session base")
  local cur_synced = git.rev_parse(root, synced_ref)
  if reset or not cur_synced or (explicit_base and cur_synced == prev_base) then git.update_ref(root, synced_ref, base, "init synced") end
  return base
end
local function activate_session(root, ses, remote, no_fetch)
  config.set_active_session(ses)
  local r = remote or repo_remote(root, ses)
  ensure_base(root, ses, not no_fetch and r or nil)
  if r and r ~= "" then local st = git.read_state(root, ses); if st.remote ~= r then st.remote = r; git.write_state(root, ses, st) end end
end
local function queue_push(root, remote, refs, on_done)
  if not remote or remote == "" then if on_done then vim.schedule(function() on_done(false) end) end; return false end
  local key = root .. "\0" .. remote
  if push_inflight[key] then
    local q = push_queued[key] or { refs = {}, cbs = {} }
    for _, r in ipairs(refs) do if not vim.tbl_contains(q.refs, r) then q.refs[#q.refs + 1] = r end end
    if on_done then q.cbs[#q.cbs + 1] = on_done end
    push_queued[key] = q; return true
  end
  push_inflight[key] = true
  local started = git.push_refs_async(root, remote, refs, function(ok, perr)
    push_inflight[key] = nil
    if not ok and perr and perr ~= "" then vim.notify("agent-track: note push failed: " .. perr, vim.log.levels.WARN) end
    if on_done then on_done(ok, perr) end
    local q = push_queued[key]
    if q then push_queued[key] = nil; queue_push(root, remote, q.refs, function(qok, qerr) for _, cb in ipairs(q.cbs) do cb(qok, qerr) end end) end
  end)
  if not started then push_inflight[key] = nil; return false end
  return true
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
function M.detach(session) local s = config.resolve_session(session); watch.detach(session); return { ok = true, session = s, active = false } end
function M.statusline() local cfg = config.get(); return (cfg.statusline and cfg.statusline.enabled ~= false) and (sl_cache or "") or "" end
function M.sessions(opts)
  local _, _, info, err = ctx_of(nil, opts); if not info then return { ok = false, error = err, sessions = {} } end
  return { ok = true, active = config.resolve_session(), sessions = (discover_sessions(info.root)) }
end
--- Every trackable session (<ref_prefix>/*/agent) with review counts, newest first.
function M.overview(opts)
  opts = opts or {}
  local _, _, info, err = ctx_of(nil, opts); if not info then return { ok = false, error = err, sessions = {} } end
  local active, keep_sl, out = config.resolve_session(), sl_cache, {}
  local names, heads = discover_sessions(info.root)
  for _, s in ipairs(names) do
    local r = M.list(s, { cwd = info.root })
    if r.ok then
      local c = r.counts
      out[#out + 1] = { session = s, active = s == active, total = c.total, approved = c.approved, rejected = c.rejected, pending = c.pending + c.stale, agent = heads[s], remote = r.remote }
    end
  end
  sl_cache = keep_sl -- list() rewrites the statusline per session; keep the active one's text
  return { ok = true, active = active, root = info.root, sessions = out }
end
local function overview_line(x)
  return string.format("%s%-24s ✓%-3d ✗%-3d ·%-3d (%d)", x.active and "*" or " ", x.session, x.approved, x.rejected, x.pending, x.total)
end
--- :AgentTrack list — print every session's accept/reject/pending, then a picker; <CR> opens its review panel.
function M.list_sessions(opts)
  local r = M.overview(opts)
  if not r.ok then return vim.notify("agent-track: " .. tostring(r.error), vim.log.levels.WARN) end
  if #r.sessions == 0 then return vim.notify("agent-track: no subcommit sessions in this repo", vim.log.levels.INFO) end
  local lines = vim.tbl_map(overview_line, r.sessions)
  vim.api.nvim_echo({ { "agent-track sessions (✓ approved  ✗ rejected  · pending)\n" .. table.concat(lines, "\n") } }, true, {})
  if #vim.api.nvim_list_uis() == 0 then return r end
  vim.ui.select(r.sessions, { prompt = "AgentTrack sessions", format_item = overview_line }, function(x)
    if x then M.session(x.session); require("agent-track.reviewer").panel({ session = x.session }) end
  end)
  return r
end
function M.session(name, opts)
  local _, _, info, err = ctx_of(nil, opts); if not info then return { ok = false, error = err } end
  if not name or name == "" then return M.sessions(opts) end
  activate_session(info.root, name, repo_remote(info.root, name))
  local lres = M.list(name, opts); return { ok = true, session = name, remote = lres.remote, base = lres.base, counts = lres.counts }
end
function M.init_session(remote_or_opts, maybe_opts)
  local opts = type(remote_or_opts) == "table" and remote_or_opts or (maybe_opts or {})
  local remote = type(remote_or_opts) == "table" and opts.remote or remote_or_opts
  local explicit_s = (type(opts.session) == "string" and opts.session ~= "") and opts.session or nil
  local s, _, info, err = ctx_of(explicit_s, opts); if not info then return { ok = false, error = err } end
  local rp, r_any, r_match, r_bases, r_agents = ref_prefix(), false, false, {}, {}
  if remote and remote ~= "" then
    local lr = git.run(info.root, { "ls-remote", remote, "HEAD", "refs/heads/*", "refs/remotes/origin/*", rp .. "/*/base", rp .. "/*/agent" }, { ident = false })
    if not lr.ok then local e = vim.trim(lr.stderr ~= "" and lr.stderr or ("cannot reach remote: " .. remote)); vim.notify("agent-track: " .. e, vim.log.levels.ERROR); return { ok = false, error = e } end
    local shas, seen_sha = {}, {}
    local bpat, apat = "^" .. vim.pesc(rp) .. "/([^/]+)/base$", "^" .. vim.pesc(rp) .. "/([^/]+)/agent$"
    for line in (lr.stdout or ""):gmatch("[^\n]+") do
      local sha, ref = line:match("^(%x+)%s+(%S+)$")
      if sha and ref then
        r_any = true
        if not seen_sha[sha] then seen_sha[sha], shas[#shas + 1] = true, sha end
        local bs = ref:match(bpat); if bs then r_bases[bs] = sha end
        local as = ref:match(apat); if as then r_agents[as] = sha end
      end
    end
    if #shas > 0 then
      local cf = git.run(info.root, { "cat-file", "--batch-check=%(objecttype)" }, { stdin = table.concat(shas, "\n") .. "\n", ident = false })
      for t in (cf.stdout or ""):gmatch("[^\n]+") do if t == "commit" or t == "tag" then r_match = true; break end end
    end
    if r_any and not r_match then
      local e = "remote does not share git history with current cwd repo (" .. info.root .. ")"
      vim.notify("agent-track: " .. e, vim.log.levels.ERROR); return { ok = false, error = e }
    end
    git.run(info.root, { "config", "--local", "agent-track.remote", remote }, { ident = false })
  end
  local eff_remote = (remote and remote ~= "" and remote) or repo_remote(info.root, s)
  if eff_remote and eff_remote ~= "" then
    local fres = M.fetch(explicit_s, { async = false, silent = opts.silent, remote = eff_remote, only_session = opts.only_session, cwd = info.root, from_init = true })
    if not fres.ok then return { ok = false, error = fres.error } end
    s = config.resolve_session(explicit_s)
    if not explicit_s and not r_bases[s] and not r_agents[s] then
      local rses = next(r_agents) or next(r_bases)
      if rses then s = rses end
    end
  end
  config.set_active_session(s)
  local base_ref, r_base = config.ref(s, "base"), r_bases[s]
  local base = ensure_base(info.root, s, nil, opts.base or (r_base and git.rev_parse(info.root, r_base .. "^{commit}")), opts.reset)
  if not base then return { ok = false, error = "cannot resolve base commit" } end
  local any_remote_session = (next(r_bases) ~= nil) or (next(r_agents) ~= nil)
  if remote and remote ~= "" and (opts.reset or opts.base ~= nil or (not r_base and not r_agents[s] and (not any_remote_session or explicit_s ~= nil))) then
    git.push_refs(info.root, remote, { base_ref })
  end
  local state = git.read_state(info.root, s); if opts.reset then state.applied_ids = {} end
  if eff_remote and eff_remote ~= "" then state.remote = eff_remote end; git.write_state(info.root, s, state)
  if eff_remote and eff_remote ~= "" and opts.watch ~= false then
    watch.attach(s, eff_remote, function() M.fetch(opts.only_session and s or nil, { async = true, silent = true, only_session = opts.only_session, cwd = info.root }) end)
  end
  local lres = M.list(s, { cwd = info.root })
  local agent_sha = git.rev_parse(info.root, config.ref(s, "agent"))
  if remote and remote ~= "" and not opts.silent then
    local b_short = (lres.base or base) and (lres.base or base):sub(1, 7) or "none"
    local a_short = agent_sha and agent_sha:sub(1, 7) or "none"
    vim.notify(string.format("agent-track [%s]: %d subcommits (base=%s, agent=%s)", s, #(lres.items or {}), b_short, a_short), vim.log.levels.INFO)
  end
  return { ok = true, session = s, remote = lres.remote or eff_remote, base = lres.base or base, agent = agent_sha, counts = lres.counts }
end
function M.fetch(session, opts)
  local explicit_s = type(session) == "table" and session.session or session
  local s, o, info, err = ctx_of(session, opts); if not info then return { ok = false, error = err } end
  local remote = o.remote or repo_remote(info.root, s); if not remote or remote == "" then return { ok = false, error = "no remote configured for session " .. s } end
  local cfg, rp = config.get(), ref_prefix()
  local np = (cfg.notes_prefix or "subcommits"):gsub("^refs/notes/", ""):gsub("/+$", "")
  local _, old_heads = discover_sessions(info.root); local old_s_head = old_heads[s]
  local fargs = o.only_session and { "fetch", remote, "+" .. config.ref(s, "agent") .. "*:" .. config.ref(s, "agent") .. "*", "+" .. config.ref(s, "base") .. "*:" .. config.ref(s, "base") .. "*", "+refs/notes/" .. np .. "/*:refs/notes/" .. np .. "/*" }
    or { "fetch", remote, "+" .. rp .. "/*/agent:" .. rp .. "/*/agent", "+" .. rp .. "/*/base:" .. rp .. "/*/base", "+refs/notes/" .. np .. "/*:refs/notes/" .. np .. "/*" }
  local function done(r)
    if not r.ok and not o.silent then
      local ferr = vim.trim(r.stderr ~= "" and r.stderr or ("git fetch failed from " .. remote))
      vim.notify("agent-track: " .. ferr, vim.log.levels.ERROR)
      return { ok = false, error = ferr }
    end
    local sessions, new_heads = discover_sessions(info.root)
    local target_s, old_agent = s, old_s_head
    if not o.only_session and not explicit_s then
      local s_nonempty = has_subcommits(info.root, s, new_heads[s])
      local changed_other
      for _, cand in ipairs(sessions) do
        if cand ~= s and new_heads[cand] ~= old_heads[cand] and has_subcommits(info.root, cand, new_heads[cand]) then changed_other = cand; break end
      end
      if not s_nonempty then
        local best = changed_other
        if not best then for _, cand in ipairs(sessions) do if has_subcommits(info.root, cand, new_heads[cand]) then best = cand; break end end end
        if best and best ~= s then target_s, old_agent = best, old_heads[best]; activate_session(info.root, target_s, remote, true) end
      elseif changed_other and new_heads[s] == old_s_head then
        activate_session(info.root, changed_other, remote, true); target_s, old_agent = changed_other, old_heads[changed_other]
      end
    end
    if target_s == s and (new_heads[target_s] or not o.from_init) then ensure_base(info.root, target_s, nil) end
    local new_agent = new_heads[target_s] or git.rev_parse(info.root, config.ref(target_s, "agent"))
    local changed = (new_agent ~= nil and new_agent ~= old_agent) or (target_s ~= s and has_subcommits(info.root, target_s, new_agent))
    local lres = M.list(target_s, { cwd = info.root })
    if changed then
      if cfg.notify_on_arrival and not o.from_init then vim.notify(string.format("agent-track [%s]: %d subcommits", target_s, #(lres.items or {})), vim.log.levels.INFO) end
      emit("AgentTrackUpdated", "on_updated", { session = target_s, agent = new_agent, previous = old_agent })
      if cfg.auto_sync_approved then M.apply("approved", { session = target_s, cwd = info.root }) end
    end
    return { ok = true, session = target_s, agent = new_agent, updated = changed, items = lres.items, counts = lres.counts }
  end
  local fkey = o.only_session and s or "*"
  if not o.async then return done(git.run(info.root, fargs, { reflog = true })) end
  if fetch_inflight[fkey] then fetch_queued[fkey] = true; return { ok = true, async = true, queued = true } end; fetch_inflight[fkey] = true
  git.run_async(info.root, fargs, { reflog = true }, function(r) fetch_inflight[fkey] = nil; done(r); if fetch_queued[fkey] then fetch_queued[fkey] = nil; M.fetch(session, o) end end)
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
  local out = { ok = true, root = info.root, session = s, remote = state.remote or repo_remote(info.root, s), base = base, synced = synced, approved_prefix = approved_prefix, items = items, counts = counts }
  update_statusline(out); return out
end

function M.review(sha_or_idx, status, opts)
  opts = opts or {}
  if not ({ approved = true, rejected = true, pending = true })[status] then return { ok = false, error = "invalid review status: " .. tostring(status) } end
  local s, _, info, err = ctx_of(opts.session, opts); if not info then return { ok = false, error = err } end
  local lres = M.list(s, { cwd = info.root }); if not lres.ok or #(lres.items or {}) == 0 then return { ok = false, error = lres.error or "no subcommits to review" } end
  local items = lres.items
  local it = git.find_item(items, sha_or_idx) or ((sha_or_idx == nil or sha_or_idx == "") and (opts.prefix and items[#items] or vim.iter(items):find(function(c) return c.review_status == "pending" or c.review_status == "stale" end) or items[#items]) or nil)
  if not it then return { ok = false, error = "subcommit not found: " .. tostring(sha_or_idx) } end
  local approved_ref, notes_arg, notes_ref = config.ref(s, "approved"), config.notes_arg(s), config.notes_ref(s)
  local function write_note(cm)
    return git.run(info.root, { "notes", "--ref=" .. notes_arg, "add", "-f", "-m", vim.json.encode({ status = status, comment = cm or "", subcommit_id = it.subcommit_id or "", patch_id = git.patch_ids(info.root, { it.sha })[it.sha] or "", updated_at = os.time() }), it.sha })
  end
  if opts.prefix and status == "approved" then git.update_ref(info.root, approved_ref, it.sha, "approve prefix"); if opts.comment and opts.comment ~= "" then write_note(opts.comment) end
  else local nr = write_note(opts.comment); if not nr.ok then return { ok = false, error = vim.trim(nr.stderr) } end end
  local pushed, push_async = false, false
  if opts.push ~= false then
    if opts.async_push then push_async = queue_push(info.root, lres.remote, { notes_ref, approved_ref }, opts.on_pushed)
    else pushed = git.push_refs(info.root, lres.remote, { notes_ref, approved_ref }) end
  end
  M.list(s, { cwd = info.root }); emit("AgentTrackReviewed", "on_reviewed", { session = s, sha = it.sha, status = status, prefix = opts.prefix == true })
  if config.get().auto_sync_approved and status == "approved" then M.apply("approved", { session = s, cwd = info.root }) end
  return { ok = true, session = s, sha = it.sha, status = status, prefix = opts.prefix == true, pushed = pushed, push_async = push_async }
end

function M.apply(target, opts)
  if type(target) == "table" then opts, target = target, target.target end
  local s, o, info, err = ctx_of(opts and opts.session, opts); if not info then return { ok = false, error = err } end
  local lres = M.list(s, { cwd = info.root }); if not lres.ok then return lres end
  local res = sync.apply(info, s, lres.items or {}, target, o); M.list(s, { cwd = info.root })
  if res.ok and not res.noop then emit("AgentTrackSynced", "on_synced", { session = s, synced = res.synced, clean = true }) end
  return res
end
function M.undo(session, opts)
  local s, _, info, err = ctx_of(session, opts); if not info then return { ok = false, error = err } end
  local res = sync.undo(info, s); M.list(s, { cwd = info.root }); if res.ok then emit("AgentTrackSynced", "on_synced", { session = s, undo = true, synced = res.restored_synced }) end; return res
end
function M.clean(session, opts)
  local s, _, info, err = ctx_of(session, opts); watch.detach(session); if not info then return { ok = false, error = err } end
  for _, name in ipairs({ "base", "agent", "synced", "approved", "undo", "state" }) do git.delete_ref(info.root, config.ref(s, name)) end
  git.delete_ref(info.root, config.notes_ref(s)); sl_cache = ""; return { ok = true, session = s, cleaned = true }
end
function M.status(session)
  local lres = M.list(config.resolve_session(session)); if not lres.ok then return lres end
  return { ok = true, root = lres.root, session = lres.session, remote = lres.remote, base = lres.base, synced = lres.synced, approved_prefix = lres.approved_prefix, counts = lres.counts, watcher = watch.status(session) }
end
function M.reload()
  local uopts = config.get_user_opts and config.get_user_opts() or nil
  local prev_s = config.resolve_session()
  pcall(watch.detach_all)
  local rev = package.loaded["agent-track.reviewer"]
  if type(rev) == "table" and type(rev.close) == "function" then pcall(rev.close) end
  package.loaded["agent-track"] = nil
  for k in pairs(package.loaded) do
    if type(k) == "string" and k:find("^agent%-track%.") then package.loaded[k] = nil end
  end
  local fresh = require("agent-track"); fresh.setup(uopts)
  if prev_s and prev_s ~= "" then require("agent-track.config").set_active_session(prev_s) end
  return { ok = true, reloaded = true, session = prev_s }
end

local SESS_SUB = { session = true, status = true, fetch = true, review = true, detach = true, undo = true, clean = true }
local CMD = {
  init = function(f) M.init_session(f[2]) end, detach = function(f) M.detach(f[2]) end, fetch = function(f) M.fetch(f[2]) end,
  reload = function() M.reload(); vim.notify("agent-track: reloaded", vim.log.levels.INFO) end,
  attach = function(f)
    if not f[2] then return vim.notify("Usage: :AgentTrack attach <remote> [session]", vim.log.levels.ERROR) end
    local r = M.attach(f[2], { session = f[3] })
    -- :AgentTrack attach (interactive only; the Lua/RPC attach stays headless) jumps straight into the first
    -- pending/stale subcommit's [track] diff. reviewer.open_on_attach = false turns this off.
    local c = r and r.ok and r.counts or nil
    if c and (c.pending or 0) + (c.stale or 0) > 0 and (config.get().reviewer or {}).open_on_attach ~= false then
      require("agent-track.reviewer").open(nil, { session = r.session })
    end
  end,
  session = function(f)
    if f[2] then
      local r = M.session(f[2]); if not r.ok then return vim.notify("agent-track: " .. tostring(r.error), vim.log.levels.ERROR) end
      local c = r.counts or { synced = 0, total = 0, pending = 0, stale = 0 }
      vim.notify(string.format("agent-track: active session -> %s (%d/%d synced, %d pending)", r.session, c.synced, c.total, c.pending + c.stale), vim.log.levels.INFO)
    else
      local r = M.sessions(); if not r.ok then return vim.notify("agent-track: " .. tostring(r.error), vim.log.levels.WARN) end
      local list = vim.tbl_map(function(x) return (x == r.active and "*" or "") .. x end, r.sessions)
      vim.notify(string.format("agent-track sessions (active=%s): %s", r.active, #list > 0 and table.concat(list, ", ") or "(none)"))
    end
  end,
  status = function(f)
    local st = M.status(f[2]); if not st.ok then return vim.notify("agent-track: " .. tostring(st.error), vim.log.levels.WARN) end; local c = st.counts
    vim.notify(string.format("agent-track [%s] remote=%s synced=%d/%d ✓%d ·%d ✗%d watch=%s", st.session, st.remote or "-", c.synced, c.total, c.approved, c.pending + c.stale, c.rejected, st.watcher.active and st.watcher.mode or "off"))
  end,
  list = function() M.list_sessions() end, open = function(f) require("agent-track.reviewer").open(f[2]) end,
  review = function(f) require("agent-track.reviewer").panel({ session = f[2] }) end,
  approve = function(f) M.review(f[2] ~= "--prefix" and f[2] or nil, "approved", { prefix = (f[2] == "--prefix" or f[3] == "--prefix") }) end,
  reject = function(f) M.review(f[2], "rejected", { comment = table.concat(vim.list_slice(f, 3), " ") }) end,
  sync = function(f) M.apply(f[2] or "approved") end, undo = function(f) M.undo(f[2]) end, clean = function(f) M.clean(f[2]) end,
}
local SUB = vim.tbl_keys(CMD); table.sort(SUB)
local function register_commands()
  if cmd_registered then return end; cmd_registered = true
  vim.api.nvim_create_user_command("AgentTrack", function(c) local sub = c.fargs[1] or "status"; if CMD[sub] then CMD[sub](c.fargs) else vim.notify("Unknown :AgentTrack subcommand: " .. sub, vim.log.levels.ERROR) end end, {
    nargs = "*", desc = "AgentTrack subcommit workflow commands",
    complete = function(lead, line)
      local p = vim.split(line, "%s+", { trimempty = true })
      local arg_idx = #p + (line:sub(-1):match("%s") and 1 or 0)
      local opts = {}
      if arg_idx <= 2 then opts = SUB
      elseif arg_idx == 3 and p[2] == "sync" then opts = { "approved", "all" }
      elseif (arg_idx == 3 and SESS_SUB[p[2]]) or (arg_idx == 4 and p[2] == "attach") then
        local info = git.root_info(); opts = info and (discover_sessions(info.root)) or {}
      end
      return vim.tbl_filter(function(s) return s:find(lead, 1, true) == 1 end, opts)
    end,
  })
end
function M.setup(opts) config.setup(opts); register_commands(); return M end
register_commands(); return M
