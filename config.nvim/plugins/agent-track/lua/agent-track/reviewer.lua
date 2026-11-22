local M = {}
local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
local BUILTIN_SELECT, BUILTIN_INPUT = vim.ui.select, vim.ui.input
local BADGE = { approved = "✓", rejected = "✗", stale = "~", pending = "·" }
local HL = { approved = "AgentTrackApproved", rejected = "AgentTrackRejected", stale = "AgentTrackStale", pending = "AgentTrackPending" }
local DEF_HL = { AgentTrackApproved = "DiagnosticOk", AgentTrackRejected = "DiagnosticError", AgentTrackStale = "DiagnosticWarn", AgentTrackPending = "Comment", AgentTrackSynced = "DiagnosticOk", AgentTrackConflict = "DiagnosticError" }
local DEF_KEYS = { next_subcommit = { "<leader>tj", "]c" }, prev_subcommit = { "<leader>tk", "[c" }, next_touch_file = "]f", prev_touch_file = "[f",
  approve = "<leader>ta", approve_comment = "<leader>tc", approve_prefix = "<leader>tA", reject = "<leader>tx", sync = "<leader>ts", panel = "<leader>tp" }
local S = { session = nil, root = nil, tab = nil, sha = nil, index = 0, touch_idx = 1 }
local function track() return require("agent-track") end
local function pane() return require("agent-track.pane") end
local function get_cfg()
  local ok, t = pcall(track); local c = ok and t.get_config and t.get_config() or {}; local r = c.reviewer or {}
  return { tab_prefix = r.tab_prefix or "[track]", reuse_tab = r.reuse_tab ~= false, keymaps = vim.tbl_extend("force", DEF_KEYS, r.keymaps or {}) }, c
end
local function ask(p, cb) if #vim.api.nvim_list_uis() > 0 or vim.ui.input ~= BUILTIN_INPUT then return vim.ui.input({ prompt = p }, cb) end; cb("") end
local function check(r) if type(r) == "table" and r.ok == false and r.error then vim.notify("agent-track: " .. r.error, vim.log.levels.WARN) end; return r end
local function rev_badge(it) return (it.review_status == "approved" and it.review_via == "prefix") and "✓*" or (BADGE[it.review_status] or "·") end
local function ordered_files(it)
  local out, seen = {}, {}
  local function add(p) p = vim.trim(tostring(p or "")); if p ~= "" and not seen[p] then seen[p], out[#out + 1] = true, p end end
  for _, p in ipairs((it and it.touch_order) or {}) do add(p) end
  for _, f in ipairs((it and it.files) or {}) do add(type(f) == "table" and f.path or f) end
  return out
end
local function touch_str(f) return #f == 0 and "" or string.format("  [Touch: %s%s]", table.concat(vim.list_slice(f, 1, 3), ", "), #f > 3 and (" +" .. (#f - 3)) or "") end
local function format_row(it)
  return string.format("%s %s%s %d. %s %s%s", it.synced and "●" or "○", rev_badge(it), it.would_conflict and " ⚡" or "",
    it.index or 0, it.short_sha or (it.sha and it.sha:sub(1, 7)) or "?", it.subject or "", touch_str(ordered_files(it)))
end
local function summary_title(res)
  local items, syn, app, pend, rej, wconf = res.items or {}, 0, 0, 0, 0, 0
  for _, it in ipairs(items) do
    syn, app, rej = syn + (it.synced and 1 or 0), app + (it.review_status == "approved" and 1 or 0), rej + (it.review_status == "rejected" and 1 or 0)
    pend, wconf = pend + ((it.review_status == "pending" or it.review_status == "stale") and 1 or 0), wconf + (it.would_conflict and 1 or 0)
  end
  local rem = res.remote and (" <- " .. vim.fn.fnamemodify(res.remote, ":t")) or ""
  return string.format("AgentTrack [%s%s] synced %d/%d | approved %d | pending %d | rejected %d | conflicts %d", res.session or "default", rem, syn, #items, app, pend, rej, wconf)
end
local function fetch_list(session)
  local res = track().list(session or S.session, { preview_conflicts = true }) or { ok = false, items = {} }
  if res.session then S.session = res.session end
  if res.root then S.root = res.root end
  S.items = res.items
  return res
end
local function resolve_item(items, target)
  if target == nil or target == "" then
    for i, it in ipairs(items) do if it.review_status == "pending" or it.review_status == "stale" then return it, i end end
    return items[#items], #items
  end
  if type(target) == "number" then return items[target], target end
  local s, n = tostring(target), tonumber(target)
  for i, it in ipairs(items) do if it.sha == s or it.short_sha == s or it.subcommit_id == s or (#s >= 4 and (it.sha or ""):sub(1, #s) == s) then return it, i end end
  return n and items[n] or nil, n or 0
end
local function git_diff(parent, sha)
  local argv = vim.deepcopy((select(2, get_cfg())).git_cmd or { "git" })
  if S.root and S.root ~= "" then vim.list_extend(argv, { "-C", S.root }) end
  local r = vim.system(vim.list_extend(argv, { "diff", "--no-color", parent, sha }), { text = true }):wait()
  return (r.code == 0 and r.stdout) or ""
end
local function close_prev_tab(keep)
  local t = S.tab
  if t and t ~= keep and not S.in_place and vim.api.nvim_tabpage_is_valid(t) and #vim.api.nvim_list_tabpages() > 1 then
    vim.api.nvim_set_current_tabpage(t); vim.cmd("silent! tabclose")
    if keep and vim.api.nvim_tabpage_is_valid(keep) then vim.api.nvim_set_current_tabpage(keep) end
    if S.tab == t then S.tab = nil end
  end
end
local OPS = {
  approve = function(t, sha, s, cb) if sha then check(t.review(sha, "approved", { session = s, async_push = true })); cb() end end,
  approve_comment = function(t, sha, s, cb) if sha then ask("Approve comment: ", function(r) if r ~= nil then check(t.review(sha, "approved", { comment = r, session = s, async_push = true })); cb() end end) end end,
  approve_prefix = function(t, sha, s, cb) if sha then check(t.review(sha, "approved", { prefix = true, session = s, async_push = true })); cb() end end,
  clear = function(t, sha, s, cb) if sha then check(t.review(sha, "pending", { comment = "", session = s, async_push = true })); cb() end end,
  reject = function(t, sha, s, cb) if sha then ask("Reject reason: ", function(r) if r ~= nil then check(t.review(sha, "rejected", { comment = r, session = s, async_push = true })); cb() end end) end end,
  sync = function(t, _, s, cb) check(t.apply("approved", { session = s })); cb() end,
  sync_prefix = function(t, sha, s, cb) if sha then check(t.apply(sha, { session = s })); cb() end end,
  undo = function(t, _, s, cb) check(t.undo(s)); cb() end, fetch = function(t, _, s, cb) check(t.fetch(s)); cb() end,
}
local function run_op(op, sha, s, cb) OPS[op](track(), sha, s, cb or function() end) end
local function install_buf_keymaps(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype == "prompt" or (vim.bo[buf].filetype or ""):find("^snacks_") then return end
  local km, refresh = (get_cfg()).keymaps, function() if S.sha then M.open(S.sha, { session = S.session }) end end
  local function advance() -- after approving: open the next pending/stale subcommit, else re-open the current one
    local items = fetch_list(S.session).items or {}
    for step = 1, #items do local it = items[((S.index - 1 + step) % #items) + 1]; if it.review_status == "pending" or it.review_status == "stale" then return M.open(it.sha, { session = S.session }) end end
    refresh()
  end
  local acts = {
    next_subcommit = M.next_subcommit, prev_subcommit = M.prev_subcommit, next_touch_file = M.next_touch_file, prev_touch_file = M.prev_touch_file,
    approve = function() run_op("approve", S.sha, S.session, advance) end, approve_comment = function() run_op("approve_comment", S.sha, S.session, advance) end,
    approve_prefix = function() run_op("approve_prefix", S.sha, S.session, refresh) end, reject = function() run_op("reject", S.sha, S.session, refresh) end,
    panel = function() M.panel({ session = S.session }) end,
    sync = function()
      local app = vim.iter(fetch_list(S.session).items or {}):any(function(x) return x.review_status == "approved" end)
      run_op(app and "sync" or "sync_prefix", S.sha, S.session, refresh)
    end,
  }
  for name, fn in pairs(acts) do -- each keymap option is one lhs or a list of lhs
    for _, lhs in ipairs(type(km[name]) == "table" and km[name] or { km[name] }) do
      if type(lhs) == "string" and lhs ~= "" then vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, desc = "AgentTrack: " .. (name:gsub("_", " ")) }) end
    end
  end
end
local function ensure_setup()
  for g, tgt in pairs(DEF_HL) do vim.api.nvim_set_hl(0, g, { link = tgt, default = true }) end
  if S.augroup then return end
  S.augroup = vim.api.nvim_create_augroup("AgentTrackReviewer", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", { group = S.augroup, callback = function(ev)
    if vim.t.agent_track_tab and vim.api.nvim_win_get_config(0).relative == "" then
      if vim.t.agent_track_tabname and vim.t.tabname ~= vim.t.agent_track_tabname then vim.t.tabname = vim.t.agent_track_tabname end
      install_buf_keymaps(ev.buf)
    end
  end })
  vim.api.nvim_create_autocmd("User", { group = S.augroup, pattern = { "AgentTrackUpdated", "AgentTrackSynced", "AgentTrackReviewed" },
    callback = function(ev)
      if ev.data and ev.data.session then S.session = ev.data.session end
      if S.picker and not S.picker.closed then pcall(function() S.picker:find() end) end
    end })
end
local function open_view(it, idx, total, touch_idx, file_only)
  ensure_setup()
  local rcfg, files = get_cfg(), ordered_files(it)
  touch_idx = #files > 0 and (((touch_idx - 1) % #files) + 1) or 0
  local cur_file, short = files[touch_idx], it.short_sha or it.sha:sub(1, 7)
  local header = string.format("[%d/%d] %s %s%s %s: %s | Touch [%d/%d]: %s", idx, total,
    it.synced and "●" or "○", rev_badge(it), it.would_conflict and " ⚡" or "", short, it.subject or "", touch_idx, #files, cur_file or "-")
  S.sha, S.index, S.touch_idx = it.sha, idx, math.max(1, touch_idx)
  local function tag_tab(tab)
    if not tab or not vim.api.nvim_tabpage_is_valid(tab) then return end
    local tname = rcfg.tab_prefix .. short
    vim.t[tab].agent_track_tab, vim.t[tab].agent_track_header, vim.t[tab].agent_track_tabname, vim.t[tab].agent_track_sha, vim.t[tab].agent_track_touch_file = true, header, tname, it.sha, cur_file
    vim.fn.settabvar(vim.api.nvim_tabpage_get_number(tab), "tabname", tname)
    local okp, perr = pcall(function() pane().show(tab, { session = S.session, root = S.root, sha = it.sha, items = S.items }) end)
    if not okp then vim.notify("agent-track pane: " .. tostring(perr), vim.log.levels.WARN) end
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do install_buf_keymaps(vim.api.nvim_win_get_buf(w)) end
    vim.schedule(function() if vim.api.nvim_tabpage_is_valid(tab) then vim.fn.settabvar(vim.api.nvim_tabpage_get_number(tab), "tabname", tname); vim.cmd("redrawtabline") end end)
    vim.cmd("redrawtabline"); vim.api.nvim_echo({ { header, "Title" } }, false, {})
  end
  local parent = (it.parent and it.parent ~= "") and it.parent or EMPTY_TREE
  if vim.fn.exists(":CodeDiff") == 2 then
    if rcfg.reuse_tab then close_prev_tab(nil) end
    local before, opened, grp = {}, false, vim.api.nvim_create_augroup("AgentTrackCodeDiffOpen", { clear = true })
    for _, t in ipairs(vim.api.nvim_list_tabpages()) do before[t] = true end
    local function finish(tab) if rcfg.reuse_tab then close_prev_tab(tab) end; S.tab, S.in_place = tab, false; tag_tab(tab) end
    vim.api.nvim_create_autocmd("User", { group = grp, pattern = "CodeDiffOpen", once = true, callback = function(ev)
      if ev.data and ev.data.tabpage and vim.api.nvim_tabpage_is_valid(ev.data.tabpage) then opened = true; finish(ev.data.tabpage) end
    end })
    local abs_file = cur_file and ((S.root and S.root ~= "") and (S.root:gsub("/+$", "") .. "/" .. cur_file) or cur_file) or nil
    local ok, err = pcall(vim.cmd, (file_only and abs_file) and ("CodeDiff file " .. parent .. " " .. it.sha .. " " .. vim.fn.fnameescape(abs_file)) or ("CodeDiff " .. parent .. " " .. it.sha))
    if not ok then pcall(vim.api.nvim_del_augroup_by_id, grp); return { ok = false, error = tostring(err) } end
    local cur = vim.api.nvim_get_current_tabpage()
    if not opened and not before[cur] then finish(cur) elseif not opened and not package.loaded["codediff"] then S.tab, S.in_place = cur, true; tag_tab(cur) end
  else
    if rcfg.reuse_tab and S.tab and vim.api.nvim_tabpage_is_valid(S.tab) then vim.api.nvim_set_current_tabpage(S.tab) else vim.cmd("tabnew"); S.tab = vim.api.nvim_get_current_tabpage() end
    S.buf = (S.buf and vim.api.nvim_buf_is_valid(S.buf)) and S.buf or vim.api.nvim_create_buf(false, true)
    vim.bo[S.buf].buftype, vim.bo[S.buf].bufhidden, vim.bo[S.buf].filetype, vim.bo[S.buf].modifiable = "nofile", "hide", "diff", true
    vim.api.nvim_win_set_buf(0, S.buf)
    local d = git_diff(parent, it.sha)
    if d == "" then d = table.concat(vim.tbl_map(function(f) return "diff --git a/" .. f .. " b/" .. f end, files), "\n") end
    vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, vim.split("# " .. header .. "\n\n" .. d, "\n")); vim.bo[S.buf].modifiable = false
    if cur_file then vim.fn.search("\\V\\^diff --git a/" .. vim.fn.escape(cur_file, "\\") .. " ", "cw") end
    tag_tab(S.tab)
  end
  return { ok = true, sha = it.sha, index = idx, touch_index = touch_idx, file = cur_file, header = header, tab = S.tab }
end
function M.open(target, opts)
  opts = opts or {}; local items = fetch_list(opts.session or require("agent-track.config").resolve_session()).items or {}; local it, idx = resolve_item(items, target)
  if not it then vim.notify("agent-track: no matching subcommit", vim.log.levels.INFO); return { ok = false, error = "no matching subcommit" } end
  return open_view(it, idx, #items, opts.touch_idx or 1, opts.file_only == true)
end
local function step_sc(d)
  local items = fetch_list(S.session).items or {}
  return #items == 0 and { ok = false, error = "no subcommits" } or open_view(items[((math.max(1, S.index) - 1 + d) % #items) + 1], ((math.max(1, S.index) - 1 + d) % #items) + 1, #items, 1, false)
end
local function step_tf(d)
  local items = fetch_list(S.session).items or {}; local it, idx = resolve_item(items, S.sha); local files = it and ordered_files(it) or {}
  return #files == 0 and { ok = false, error = "no touch files" } or open_view(it, idx, #items, ((S.touch_idx - 1 + d) % #files) + 1, true)
end
M.next_subcommit, M.prev_subcommit, M.next_touch_file, M.prev_touch_file = function() return step_sc(1) end, function() return step_sc(-1) end, function() return step_tf(1) end, function() return step_tf(-1) end
function M.close()
  if S.picker and not S.picker.closed then pcall(function() S.picker:close() end) end
  local tab = S.tab; close_prev_tab(nil)
  if tab and vim.api.nvim_tabpage_is_valid(tab) then vim.t[tab].agent_track_tab, vim.t[tab].agent_track_header, vim.t[tab].tabname = nil, nil, nil end
  S.picker, S.tab, S.in_place = nil, nil, false; return { ok = true, closed = true }
end
function M.panel(opts)
  opts = opts or {}; ensure_setup()
  local session = opts.session or require("agent-track.config").resolve_session(); local init_res = fetch_list(session)
  local ok, items, prompt = init_res.ok ~= false, init_res.items or {}, summary_title(init_res)
  if type(_G.Snacks) == "table" and _G.Snacks.picker then
    local act_map = { a = "approve", C = "approve_comment", A = "approve_prefix", x = "reject", c = "clear", s = "sync", S = "sync_prefix", u = "undo", r = "fetch" }
    local actions, keys = {}, {}
    for k, op in pairs(act_map) do
      actions["sc_" .. op] = function(p, item)
        run_op(op, item and item._sc and item._sc.sha, op == "fetch" and opts.session or (opts.session or S.session), function() if p and not p.closed then p:find() end end)
      end
      keys[k] = { "sc_" .. op, mode = "n" }
    end
    S.picker = (type(_G.Snacks.picker.pick) == "function" and _G.Snacks.picker.pick or _G.Snacks.picker)({
      title = prompt, focus = "list", on_close = function() S.picker = nil end, actions = actions, win = { input = { keys = keys }, list = { keys = keys } },
      confirm = function(p, item) p:close(); if item and item._sc then M.open(item._sc.sha, { session = opts.session or S.session }) end end,
      finder = function(_, ctx)
        local res, p, out = init_res or fetch_list(opts.session or S.session), (ctx and ctx.picker) or S.picker, {}; init_res = nil
        if p then p.title = summary_title(res); pcall(function() p:update_titles() end) end
        for i, it in ipairs(res.items or {}) do out[i] = { idx = i, text = format_row(it), _sc = it } end; return out
      end,
      format = function(item) local it = item._sc; return {
        { it.synced and "● " or "○ ", it.synced and "AgentTrackSynced" or "AgentTrackPending" }, { rev_badge(it) .. " ", HL[it.review_status] or "AgentTrackPending" },
        { it.would_conflict and "⚡ " or "", "AgentTrackConflict" }, { tostring(it.index or item.idx) .. ". ", "Number" },
        { (it.short_sha or it.sha:sub(1, 7)) .. " ", "Identifier" }, { it.subject or "" }, { touch_str(ordered_files(it)), "Directory" } }
      end,
      preview = function(ctx)
        local it = ctx.item and ctx.item._sc; if not it then return ctx.preview:set_lines({ "No subcommits" }) end
        local out = { string.format("Subcommit #%d  %s  [%s]", it.index or 0, it.sha, it.review_status or "pending"), "Keys: <CR> diff  a/A approve  C approve+comment  x reject  c clear  s/S sync  u undo  r fetch" }
        if (it.comment or "") ~= "" then out[#out + 1] = "Comment: " .. it.comment end
        if vim.trim(it.body or "") ~= "" then out[#out + 1] = "\n" .. vim.trim(it.body) end
        out[#out + 1] = "\nTouch-Order:"; for i, f in ipairs(ordered_files(it)) do out[#out + 1] = string.format("  %d. %s", i, f) end
        local d = git_diff((it.parent or "") ~= "" and it.parent or EMPTY_TREE, it.sha); if d ~= "" then out[#out + 1] = "\n" .. d end
        ctx.preview:set_lines(vim.split(table.concat(out, "\n"), "\n")); pcall(function() ctx.preview:highlight({ ft = "diff" }) end)
      end,
    })
    return { ok = ok, backend = "snacks", prompt = prompt, count = #items, lines = vim.tbl_map(format_row, items) }
  end
  if #vim.api.nvim_list_uis() > 0 or vim.ui.select ~= BUILTIN_SELECT then vim.ui.select(items, { prompt = prompt, format_item = format_row }, function(c) if c then M.open(c.sha, { session = session }) end end) end
  return { ok = ok, backend = "select", prompt = prompt, items = items, lines = vim.tbl_map(format_row, items) }
end
function M.status()
  local open = S.tab ~= nil and vim.api.nvim_tabpage_is_valid(S.tab)
  return { open = open, session = S.session, sha = S.sha, index = S.index, touch_idx = S.touch_idx, tab = open and S.tab or nil }
end
return M
