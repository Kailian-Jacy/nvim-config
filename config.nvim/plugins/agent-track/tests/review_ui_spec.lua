-- Headless UI spec for the [track] CodeDiff review tab: subcommit pane, tree explorer,
-- Touch-Order stepping, next/prev + comment-approve keys, picker <c-q> quickfix. Needs git >= 2.38, python3, codediff.nvim.
--   nvim --headless -u NONE -i NONE -n -l config.nvim/plugins/agent-track/tests/review_ui_spec.lua
-- Env: AGENT_TRACK_CODEDIFF=<codediff.nvim checkout> (default: lazy.nvim install dir).
local api = vim.api
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local PLUGIN, REPO = vim.fn.fnamemodify(here, ":h"), vim.fn.fnamemodify(here, ":h:h:h:h")
local CODEDIFF = vim.env.AGENT_TRACK_CODEDIFF or vim.fn.stdpath("data") .. "/lazy/codediff.nvim"
local AT = REPO .. "/.agents/skills/agent-track/scripts/agent_track.py"
local passed, failed = 0, 0
local function check(cond, msg) if cond then passed = passed + 1 else failed = failed + 1; io.write("FAIL: " .. msg .. "\n") end end
local function eq(a, b, msg) check(a == b, string.format("%s (expected %s, got %s)", msg, vim.inspect(b), vim.inspect(a))) end
local function wait(cond, ms) return vim.wait(ms or 5000, function() local ok, v = pcall(cond); return ok and v end, 20) end
local function sh(argv, cwd)
  local r = vim.system(argv, { cwd = cwd, text = true }):wait()
  assert(r.code == 0, table.concat(argv, " ") .. "\n" .. (r.stderr or ""))
  return vim.trim(r.stdout or "")
end
local function skip(why) io.write("SKIP: " .. why .. "\n"); os.exit(0) end

local gv = vim.system({ "git", "--version" }, { text = true }):wait().stdout or ""
local maj, min = gv:match("(%d+)%.(%d+)")
if not maj or tonumber(maj) * 100 + tonumber(min) < 238 then skip("git >= 2.38 required, found: " .. vim.trim(gv)) end
if vim.fn.isdirectory(CODEDIFF) == 0 then skip("codediff.nvim not found at " .. CODEDIFF) end
if vim.fn.executable("python3") == 0 then skip("python3 not found") end

-- Agent replica R: base + 3 subcommits written by the real CLI; human repo L: a clone of R.
local tmp = vim.fn.tempname(); local R, L = tmp .. "/R", tmp .. "/L"
vim.fn.mkdir(R .. "/src/core", "p"); vim.fn.mkdir(R .. "/src/ui", "p"); vim.fn.mkdir(R .. "/tests", "p")
local function write(path, s) local f = assert(io.open(R .. "/" .. path, "w")); f:write(s); f:close() end
sh({ "git", "init", "-q", "-b", "main", R }); sh({ "git", "config", "user.name", "t" }, R); sh({ "git", "config", "user.email", "t@t" }, R)
write("src/core/math.lua", "local M = {}\nfunction M.add(a, b) return a + b end\nreturn M\n")
write("src/ui/view.lua", "return { render = function() return 'v1' end }\n"); write("tests/basic_spec.lua", "print('ok')\n"); write("README.md", "# demo\n")
sh({ "git", "add", "-A" }, R); sh({ "git", "commit", "-qm", "base" }, R)
local function subcommit(msg, files, order)
  sh({ "python3", AT, "--no-nvim", "-C", R, "subcommit", "--session", "demo", "-m", msg, "--files", files, "--order", order or files })
end
sh({ "python3", AT, "--no-nvim", "-C", R, "init-agent", "--session", "demo" })
write("src/core/math.lua", "local M = {}\nfunction M.add(a, b) return a + b end\nfunction M.backoff(n) return 2 ^ n end\nreturn M\n")
subcommit("core: add retry backoff math with jitter and caps", "src/core/math.lua")
write("src/ui/view.lua", "return { render = function() return 'v2' end }\n"); write("tests/basic_spec.lua", "assert(true)\n")
subcommit("ui: render backoff in view", "src/ui/view.lua,tests/basic_spec.lua", "tests/basic_spec.lua,src/ui/view.lua")
write("README.md", "# demo\n\nRetry docs.\n"); subcommit("docs: describe retry", "README.md")
sh({ "git", "clone", "-q", R, L })

-- Editor: real codediff opts from lua/plugins/git.lua, local agent-track plugin, leader = <Space>.
vim.o.columns, vim.o.lines, vim.g.mapleader = 180, 45, " "
vim.opt.rtp:prepend(CODEDIFF); vim.opt.rtp:prepend(PLUGIN); vim.cmd("runtime! plugin/codediff.lua")
local cd_spec
vim.g.modules = vim.g.modules or {} -- git.lua reads vim.g.modules.svn at load time
for _, s in ipairs(dofile(REPO .. "/config.nvim/lua/plugins/git.lua")) do if s[1] == "esmuellert/codediff.nvim" then cd_spec = s end end
require("codediff").setup(cd_spec and cd_spec.opts or {})
vim.cmd.cd(L)
local at, pane, rv, lc = require("agent-track").setup({ notify_on_arrival = false }), require("agent-track.pane"), require("agent-track.reviewer"), require("codediff.ui.lifecycle")
local function cur() return api.nvim_get_current_tabpage() end
local function explorer() return lc.get_explorer(cur()) end
local function map(buf, lhs) return api.nvim_buf_call(buf, function() return vim.fn.maparg(lhs, "n", false, true) end) end
local function press(buf, lhs) local m = map(buf, lhs); check(m.buffer == 1 and m.callback ~= nil, "buffer-local mapping " .. lhs .. " in buf " .. buf); if m.callback then m.callback() end end
local function opened(sha) return wait(function() local t = cur(); return vim.t[t].agent_track_sha == sha and explorer() and pane.get(t) and pane.get(t).win end) end
local function note(repo, sha)
  local r = vim.system({ "git", "-C", repo, "notes", "--ref=subcommits/demo", "show", sha }, { text = true }):wait()
  return r.code == 0 and vim.json.decode(r.stdout) or nil
end

vim.cmd("AgentTrack attach " .. vim.fn.fnameescape(R) .. " demo")
local ar = { ok = at.list("demo").ok }
check(ar.ok, "attach local agent repo")
local items = at.list("demo").items
eq(#items, 3, "three subcommits fetched into L")
check(opened(items[1].sha), ":AgentTrack attach opens the first pending subcommit's [track] diff")
rv.close(); api.nvim_set_current_win(api.nvim_list_wins()[1])

-- 0. review picker <c-q> (its qflist action) -> quickfix list whose <CR> / :cnext open subcommit diffs.
--    Snacks is stubbed: the spec captures the picker opts and runs the action <c-q> resolves to (a real snacks
--    picker can segfault *headless* nvim intermittently; the real keypress was verified under a UI).
local home_win, home_buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
local real_snacks, popts = rawget(_G, "Snacks"), nil
_G.Snacks = { picker = { pick = function(o) popts = o; return { closed = true } end } }
rv.panel({ session = "demo" }); _G.Snacks = real_snacks
check(popts and popts.actions and type(popts.actions.qflist) == "function", "review picker overrides the snacks qflist action (<c-q>)")
local rows, closed = {}, false; for i, it in ipairs(items) do rows[i] = { idx = i, _sc = it } end
popts.actions.qflist({ main = home_win, selected = function() return {} end, items = function() return rows end, close = function() closed = true end })
check(closed, "<c-q> closes the picker")
local q = vim.fn.getqflist({ title = 0, items = 0, qfbufnr = 0 })
eq(q.title, "AgentTrack [demo]", "<c-q> in the review picker builds the agent-track quickfix list"); eq(#q.items, 3, "one quickfix entry per subcommit")
eq(api.nvim_buf_get_lines(q.qfbufnr, 1, 2, false)[1]:sub(1, 11), items[2].short_sha .. "|2| ", "quickfix rows read <sha>|<index>| ...")
api.nvim_win_set_cursor(0, { 2, 0 }); api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
check(opened(items[2].sha), "<CR> on a quickfix entry opens that subcommit's [track] diff")
eq(api.nvim_win_get_buf(home_win), home_buf, "the quickfix jump window keeps its own buffer")
vim.cmd("cnext"); check(opened(items[3].sha), ":cnext (<leader>qj) steps to the next subcommit's diff")
local ph = vim.fn.bufnr("agenttrack://demo/" .. items[2].sha)
check(ph > 0 and not vim.bo[ph].buflisted and not api.nvim_buf_is_loaded(ph), "quickfix placeholder buffers stay unlisted and unloaded")

-- 1. explorer opens as a directory tree; pane docks directly under it in the same column
eq(require("codediff.config").options.explorer.view_mode, "tree", "git.lua makes the CodeDiff explorer a tree by default")
rv.open(1, { session = "demo" }); check(opened(items[1].sha), "subcommit #1 opens with explorer + pane")
local tab, ex, P = cur(), explorer(), pane.get()
check(wait(function() return #vim.tbl_filter(function(n) return n.data and n.data.type == "directory" end, (function()
  local out = {}; for l = 1, api.nvim_buf_line_count(ex.bufnr) do out[#out + 1] = ex.tree:get_node(l) end; return out end)()) > 0 end), "explorer renders directory nodes (tree view)")
local ep, pp = api.nvim_win_get_position(ex.winid), api.nvim_win_get_position(P.win)
eq(pp[2], ep[2], "pane shares the explorer column"); check(pp[1] > ep[1], "pane sits below the explorer")
eq(api.nvim_win_get_width(P.win), api.nvim_win_get_width(ex.winid), "pane width = explorer width")
eq(api.nvim_win_get_height(P.win), 4, "pane height = header + 3 rows")
eq(vim.wo[P.win].number, false, "pane has no number column"); eq(vim.wo[P.win].winfixheight, true, "pane height is fixed")
local lines = api.nvim_buf_get_lines(P.buf, 0, -1, false)
check(lines[1]:find("^ Subcommits %(3%)") ~= nil, "pane header: " .. lines[1])
check(lines[2]:find("core: add retry", 1, true) and lines[4]:find("docs: describe retry", 1, true), "pane rows in order")
check(lines[2]:find("…", 1, true) and vim.fn.strdisplaywidth(lines[2]) <= api.nvim_win_get_width(P.win), "long subjects are truncated to the column width")
check(lines[2]:find("^ · 1 ") ~= nil, "row starts with the review badge (no sync circle)")
check(vim.iter({ "⚡", "○", "●" }):all(function(g) return not table.concat(lines, "\n"):find(g, 1, true) end), "no ⚡ / sync circles in the pane")
local cur_rows = vim.tbl_map(function(m) return m[2] end, vim.tbl_filter(function(m) return m[4].line_hl_group ~= nil end,
  api.nvim_buf_get_extmarks(P.buf, -1, 0, -1, { details = true })))
eq(vim.inspect(cur_rows), vim.inspect({ 1 }), "only the open subcommit row is highlighted")
eq(#vim.tbl_filter(function(t) return vim.t[t].agent_track_tab end, api.nvim_list_tabpages()), 1, "single reused [track] tab")

-- 2. keys exist on explorer + pane buffers; <leader>tj / <leader>tk step subcommits
for _, b in ipairs({ ex.bufnr, P.buf }) do for _, lhs in ipairs({ "<leader>tj", "<leader>tk", "]c", "[c", "<leader>tc", "<leader>ta" }) do
  check(map(b, lhs).buffer == 1, "mapping " .. lhs .. " on " .. vim.bo[b].filetype)
end end
press(ex.bufnr, "<leader>tj"); check(opened(items[2].sha), "<leader>tj opens subcommit #2")
eq(#vim.tbl_filter(function(t) return vim.t[t].agent_track_tab end, api.nvim_list_tabpages()), 1, "still one [track] tab after jumping")

-- 3. Touch-Order: #2 starts at tests/basic_spec.lua (not the alphabetical first), ]f stays in the same tab
check(wait(function() return explorer().current_file_path == "tests/basic_spec.lua" end), "explorer starts at Touch-Order #1")
tab = cur(); rv.next_touch_file()
check(wait(function() return explorer().current_file_path == "src/ui/view.lua" end), "]f selects Touch-Order #2 inside the explorer")
eq(cur(), tab, "]f keeps the same tab (tree + pane stay visible)")
check(pane.get(tab).win ~= nil, "pane survives ]f")
press(explorer().bufnr, "<leader>tk"); check(opened(items[1].sha), "<leader>tk goes back to #1")
-- a file-only open that cannot select in place (another subcommit's tab) reopens the explorer at that file; it used to
-- run `:CodeDiff file <rev> <rev> <path>` (a codediff usage error) after closing the tab, leaving a [No Name] buffer
rv.open(items[2].sha, { session = "demo", file_only = true, touch_idx = 2 })
check(opened(items[2].sha) and wait(function() return explorer().current_file_path == "src/ui/view.lua" end), "file-only open of another subcommit lands on its Touch-Order file")
check(api.nvim_buf_get_name(0) ~= "", "the review tab never leaves you on a [No Name] buffer")
eq(#vim.tbl_filter(function(t) return vim.t[t].agent_track_tab end, api.nvim_list_tabpages()), 1, "file-only reopen still keeps one [track] tab")
rv.open(items[1].sha, { session = "demo" }); check(opened(items[1].sha), "back on #1")

-- 4. <leader>tc: comment + approve, note reaches R, then advance to next pending
local orig_input = vim.ui.input
vim.ui.input = function(_, cb) cb("LGTM; rename backoff later") end
press(explorer().bufnr, "<leader>tc")
local n1 = note(L, items[1].sha)
eq(n1 and n1.status, "approved", "<leader>tc approves"); eq(n1 and n1.comment, "LGTM; rename backoff later", "<leader>tc stores the comment")
check(opened(items[2].sha), "<leader>tc advances to the next pending subcommit")
check(wait(function() local n = note(R, items[1].sha); return n and n.comment == "LGTM; rename backoff later" end), "comment pushed back to agent repo R")
local inbox = vim.json.decode(sh({ "python3", AT, "--no-nvim", "-C", R, "inbox", "--session", "demo", "--json" }))
eq(inbox.items[1].comment, "LGTM; rename backoff later", "agent inbox shows the approval comment")
check(api.nvim_buf_get_lines(pane.get().buf, 1, 2, false)[1]:find("✓", 1, true) ~= nil, "pane marks #1 approved")

-- 5. pane-local keys act on the row under the cursor
P = pane.get(); api.nvim_set_current_win(P.win); api.nvim_win_set_cursor(P.win, { 2, 0 }); press(P.buf, "p")
local fl = vim.tbl_filter(function(w) return api.nvim_win_get_config(w).relative ~= "" end, api.nvim_tabpage_list_wins(0))
check(#fl == 1 and table.concat(api.nvim_buf_get_lines(api.nvim_win_get_buf(fl[1]), 0, -1, false), "\n"):find("with jitter and caps", 1, true) ~= nil, "pane p shows the full (untruncated) message in a float")
for _, w in ipairs(fl) do api.nvim_win_close(w, true) end
api.nvim_set_current_win(P.win); api.nvim_win_set_cursor(P.win, { 4, 0 })
vim.ui.input = function(_, cb) cb("docs ok") end
press(P.buf, "C"); eq((note(L, items[3].sha) or {}).comment, "docs ok", "pane C comment-approves the row under cursor")
api.nvim_win_set_cursor(P.win, { 4, 0 }); press(P.buf, "<CR>"); check(opened(items[3].sha), "pane <CR> opens the row under cursor")
vim.ui.input = orig_input

-- 6. pane follows the explorer through <leader>b hide/show; a user-closed pane stays closed
tab, ex = cur(), explorer()
require("codediff.ui.explorer").toggle_visibility(ex); check(wait(function() return pane.get(tab).win == nil end), "pane hides with the explorer")
require("codediff.ui.explorer").toggle_visibility(ex)
check(wait(function() local w = pane.get(tab).win; return w and api.nvim_win_get_position(w)[2] == api.nvim_win_get_position(ex.winid)[2] end), "pane returns under the explorer")
api.nvim_win_close(pane.get(tab).win, true); vim.wait(100)
require("codediff.ui.explorer").toggle_visibility(ex); require("codediff.ui.explorer").toggle_visibility(ex); vim.wait(200)
check(pane.get(tab).win == nil and pane.get(tab).user_closed, "user-closed pane is not resurrected")

-- 7. a new subcommit streamed from R appears in the pane of the next opened tab
write("src/ui/view.lua", "return { render = function() return 'v3' end }\n"); subcommit("ui: tidy view", "src/ui/view.lua")
at.fetch("demo", { async = false }); rv.open(4, { session = "demo" })
check(wait(function() local p = pane.get(); return p and p.win and api.nvim_buf_get_lines(p.buf, 0, 1, false)[1]:find("%(4%)") end), "pane lists the streamed 4th subcommit")

at.detach("demo")
io.write(string.format("review_ui_spec: %d passed, %d failed\n", passed, failed))
vim.fn.delete(tmp, "rf"); os.exit(failed > 0 and 1 or 0)
