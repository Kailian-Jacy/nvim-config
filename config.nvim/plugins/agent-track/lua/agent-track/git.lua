local config = require("agent-track.config")
local M, ident_cache = {}, {}

function M.resolve_bin(argv)
  if argv[1] and not argv[1]:find("/") then local ex = vim.fn.exepath(argv[1]); if ex ~= "" then argv[1] = ex end end
  return argv
end

local function spawn(root, args, opts, cb)
  opts = opts or {}
  local cfg, env = config.get(), opts.env and vim.tbl_extend("force", {}, opts.env) or {}
  if not env.GIT_SSH_COMMAND and not vim.env.GIT_SSH_COMMAND and cfg.ssh_cmd and #cfg.ssh_cmd > 0 then
    env.GIT_SSH_COMMAND = table.concat(vim.tbl_map(function(a) return a:find("[%s\"']") and vim.fn.shellescape(a) or a end, cfg.ssh_cmd), " ")
  end
  local gcmd = cfg.git_cmd or { "git" }
  local argv = M.resolve_bin(vim.deepcopy(gcmd))
  if root then vim.list_extend(argv, { "-C", root }) end
  vim.list_extend(argv, { "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false" })
  if opts.reflog then vim.list_extend(argv, { "-c", "core.logAllRefUpdates=always" }) end
  if root and opts.ident ~= false then
    if not ident_cache[root] then
      local out = vim.system(M.resolve_bin(vim.list_extend(vim.deepcopy(gcmd), { "-C", root, "config", "--get-regexp", "^user\\.(name|email)$" })), { text = true }):wait().stdout or ""
      ident_cache[root] = { n = not out:find("user%.name%s+%S"), e = not out:find("user%.email%s+%S") }
    end
    if ident_cache[root].n then vim.list_extend(argv, { "-c", "user.name=agent-track" }) end
    if ident_cache[root].e then vim.list_extend(argv, { "-c", "user.email=agent-track@local" }) end
  end
  local wrap = function(r) return { ok = r.code == 0, code = r.code, stdout = r.stdout or "", stderr = r.stderr or "" } end
  local sopts = { cwd = opts.cwd or root, env = next(env) and env or nil, stdin = opts.stdin, text = opts.text ~= false }
  return cb and vim.system(vim.list_extend(argv, args), sopts, vim.schedule_wrap(function(r) cb(wrap(r)) end)) or wrap(vim.system(vim.list_extend(argv, args), sopts):wait())
end

function M.run(root, args, opts) return spawn(root, args, opts) end
function M.run_async(root, args, opts, cb) return spawn(root, args, opts, cb) end
function M.is_ancestor(root, anc, desc) return (anc and desc) and M.run(root, { "merge-base", "--is-ancestor", anc, desc }, { ident = false }).ok or false end
function M.update_ref(root, ref, sha, msg) return M.run(root, { "update-ref", "-m", msg or "agent-track", ref, sha }, { reflog = true }) end
function M.delete_ref(root, ref) return M.run(root, { "update-ref", "-d", ref }, { reflog = true }) end
function M.root_info(cwd)
  local r = M.run(nil, { "-C", cwd or vim.fn.getcwd(), "rev-parse", "--path-format=absolute", "--show-toplevel", "--git-dir", "--git-common-dir" }, { ident = false })
  if not r.ok then return nil, vim.trim(r.stderr ~= "" and r.stderr or "not a git repository") end
  local l = vim.split(vim.trim(r.stdout), "\n", { plain = true }); return { root = l[1], git_dir = l[2], common_dir = l[3] }
end
function M.rev_parse(root, rev)
  local r = (rev and rev ~= "") and M.run(root, { "rev-parse", "--verify", "--quiet", rev }, { ident = false }) or nil
  local sha = (r and r.ok) and vim.trim(r.stdout) or ""; return sha ~= "" and sha or nil
end
-- Notes are append-only and both sides append, so they are never force-pushed: a rejected push means the remote
-- gained lines; the caller merges (M.merge_remote_notes) and retries. Other refs keep force semantics.
local function spec(r) return (r:find("^refs/notes/") and "" or "+") .. r .. ":" .. r end
M.REMOTE_NOTES = "refs/agent-track/remote-notes/"
--- After fetching notes into REMOTE_NOTES<np>/*, union them into the local refs/notes/<np>/* (cat_sort_uniq).
function M.merge_remote_notes(root, np)
  local r = M.run(root, { "for-each-ref", "--format=%(refname)", M.REMOTE_NOTES .. np .. "/" }, { ident = false })
  for ref in (r.ok and r.stdout or ""):gmatch("[^\n]+") do
    local name = ref:sub(#M.REMOTE_NOTES + 1); local lref = "refs/notes/" .. name
    if not M.rev_parse(root, lref) then M.update_ref(root, lref, M.rev_parse(root, ref), "agent-track: notes from remote")
    elseif M.rev_parse(root, lref) ~= M.rev_parse(root, ref) then M.run(root, { "notes", "--ref=" .. name, "merge", "-q", "-s", "cat_sort_uniq", ref }) end
  end
end
function M.push_refs(root, remote, refs)
  local specs = {}
  for _, r in ipairs((remote and remote ~= "") and refs or {}) do if M.rev_parse(root, r) then specs[#specs + 1] = spec(r) end end
  local pr = #specs > 0 and M.run(root, vim.list_extend({ "push", remote }, specs)) or nil
  return pr ~= nil and pr.ok, (pr and not pr.ok) and vim.trim(pr.stderr) or nil
end
function M.push_refs_async(root, remote, refs, cb)
  local specs = {}
  for _, r in ipairs((remote and remote ~= "") and refs or {}) do if M.rev_parse(root, r) then specs[#specs + 1] = spec(r) end end
  if #specs == 0 then if cb then vim.schedule(function() cb(false, nil) end) end; return nil end
  return M.run_async(root, vim.list_extend({ "push", remote }, specs), nil, function(pr)
    if cb then cb(pr.ok, not pr.ok and vim.trim(pr.stderr) or nil) end
  end)
end
function M.read_state(root, session)
  local s = config.resolve_session(session); local sha = M.rev_parse(root, config.ref(s, "state"))
  local ok, dec = pcall(vim.json.decode, sha and M.run(root, { "cat-file", "-p", sha }, { ident = false }).stdout or "")
  local st = (ok and type(dec) == "table") and dec or {}
  st.session, st.applied_ids = st.session or s, type(st.applied_ids) == "table" and st.applied_ids or {}
  return st
end
function M.write_state(root, session, st)
  local s = config.resolve_session(session)
  local r = M.run(root, { "hash-object", "-w", "--stdin" }, { stdin = vim.json.encode({ remote = st.remote, session = s, applied_ids = st.applied_ids or {} }), ident = false })
  local blob = r.ok and vim.trim(r.stdout) or nil; if blob then M.update_ref(root, config.ref(s, "state"), blob, "state update") end; return blob
end
function M.patch_ids(root, shas)
  local map, dt = {}, (shas and #shas > 0) and M.run(root, { "diff-tree", "-p", "--stdin" }, { stdin = table.concat(shas, "\n") .. "\n", ident = false }) or nil
  for line in ((dt and dt.ok and dt.stdout ~= "") and M.run(root, { "patch-id", "--stable" }, { stdin = dt.stdout, ident = false }).stdout or ""):gmatch("[^\n]+") do
    local p, c = line:match("^(%x+)%s+(%x+)"); if p and c then map[c] = p end
  end
  for _, s in ipairs(shas or {}) do map[s] = map[s] or "" end; return map
end
--- Review notes are append-only JSONL, one event per line (git notes append; union-merged on fetch):
---   {"t":"review","status":"approved|rejected|pending","at":<epoch>,"subcommit_id":..,"patch_id":..}   latest wins
---   {"t":"comment","path":"a/b.lua","side":"new|old","line":12,"end_line":14,"body":"..","at":<epoch>}
--- Comments are independent of the review status; a subcommit may carry any number of them.
--- A legacy single-object note {"status","comment",...} still reads as one review (+ one file-less comment).
function M.parse_note(raw)
  local ev = {}
  for line in (raw or ""):gmatch("[^\n]+") do
    local ok, o = pcall(vim.json.decode, vim.trim(line))
    if ok and type(o) == "table" then
      if o.t == "review" or o.t == "comment" then ev[#ev + 1] = o
      elseif o.status then
        local at = tonumber(o.updated_at) or 0
        ev[#ev + 1] = { t = "review", status = o.status, at = at, subcommit_id = o.subcommit_id, patch_id = o.patch_id }
        if (o.comment or "") ~= "" then ev[#ev + 1] = { t = "comment", body = o.comment, at = at } end
      end
    end
  end
  for i, e in ipairs(ev) do e._i = i end
  table.sort(ev, function(a, b) local x, y = tonumber(a.at) or 0, tonumber(b.at) or 0; if x ~= y then return x < y end; return a._i < b._i end)
  local review, comments = nil, {}
  for _, e in ipairs(ev) do e._i = nil; if e.t == "review" then review = e else comments[#comments + 1] = e end end
  return { review = review, comments = comments, subcommit_id = review and review.subcommit_id or nil }
end
--- Append one event line to sha's note (creates the note if absent). Never rewrites earlier lines.
function M.append_note(root, notes_arg, sha, event)
  event.at = event.at or os.time()
  return M.run(root, { "notes", "--ref=" .. notes_arg, "append", "--no-separator", "-m", vim.json.encode(event), sha }) -- notes commit: needs an ident
end
function M.notes_by_subcommit_id(root, notes_arg)
  local nref, by_id = "refs/notes/" .. notes_arg, {}
  if not M.rev_parse(root, nref) then return by_id end
  local listed = M.run(root, { "notes", "--ref=" .. notes_arg, "list" }, { ident = false })
  local blobs = {}
  for line in (listed.ok and listed.stdout or ""):gmatch("[^\n]+") do local b = line:match("^(%x+)"); if b then blobs[#blobs + 1] = b end end
  if #blobs == 0 then return by_id end
  local cat = M.run(root, { "cat-file", "--batch=\30%(objectname)" }, { stdin = table.concat(blobs, "\n") .. "\n", ident = false })
  for chunk in (cat.ok and cat.stdout or ""):gmatch("\30%x+\n([^\30]*)") do
    local n = M.parse_note(chunk); local id = n.subcommit_id
    if type(id) == "string" and id ~= "" and n.review and (not by_id[id] or (tonumber(n.review.at) or 0) >= (tonumber(by_id[id].at) or 0)) then by_id[id] = n.review end
  end
  return by_id
end
function M.find_item(items, target)
  if target == nil or target == "" then return nil elseif type(target) == "number" then return items[target] end
  local s = tostring(target)
  for _, it in ipairs(items) do if it.sha == s or it.short_sha == s or it.subcommit_id == s or (#s >= 4 and it.sha:sub(1, #s) == s) then return it end end
  return tonumber(s) and items[tonumber(s)] or nil
end

local function last_tok(s) local t = vim.split(s or "", "\t", { plain = true, trimempty = true }); return #t > 0 and vim.trim(t[#t]) or nil end
function M.log_subcommits(root, base, agent, notes_arg)
  if not base or not agent or base == agent then return {} end
  local fmt = "%x1e%H%x00%h%x00%P%x00%at%x00%s%x00%b%x00%(trailers:key=Subcommit-Id,valueonly=true,separator=%x09)%x00%(trailers:key=Touch-Order,valueonly=true,separator=,)%x00%N%x1f"
  local args = { "log", "--reverse", "--name-status", "--format=" .. fmt }
  if notes_arg and M.rev_parse(root, "refs/notes/" .. notes_arg) then args[#args + 1] = "--notes=" .. notes_arg end
  args[#args + 1] = base .. ".." .. agent
  local r, items = M.run(root, args, { ident = false }), {}
  for rec in (r.ok and r.stdout or ""):gmatch("\x1e([^\x1e]+)") do
    local sep = rec:find("\x1f", 1, true)
    if sep then
      local f, smap, changed, touch, files, seen = vim.split(rec:sub(1, sep - 1), "\0", { plain = true }), {}, {}, {}, {}, {}
      for line in rec:sub(sep + 1):gmatch("[^\n]+") do
        local st, p1, p2 = line:match("^([A-Z]%d*)\t([^\t]+)\t?(.*)$"); local p = (p2 and p2 ~= "") and p2 or p1
        if st and p then smap[p], changed[#changed + 1] = st:sub(1, 1), p end
      end
      local function add_f(p, to_touch)
        p = vim.trim(p or ""); if p ~= "" and not seen[p] then seen[p], files[#files + 1] = true, { path = p, status = smap[p] or "M" }; if to_touch then touch[#touch + 1] = p end end
      end
      for _, p in ipairs(vim.split(f[8] or "", ",", { plain = true, trimempty = true })) do add_f(p, true) end
      local fill = #touch == 0; for _, p in ipairs(changed) do add_f(p, fill) end
      local nraw = vim.trim(f[9] or ""); local note = nraw ~= "" and M.parse_note(nraw) or nil
      items[#items + 1] = { index = #items + 1, sha = f[1], short_sha = f[2], parent = vim.split(vim.trim(f[3] or ""), " ", { plain = true, trimempty = true })[1] or base,
        author_time = tonumber(f[4]) or 0, subject = f[5] or "", body = vim.trim(f[6] or ""), subcommit_id = last_tok(f[7]),
        touch_order = touch, direct_note = note and note.review or nil, comments = note and note.comments or {}, files = files }
    end
  end
  return items
end
return M
