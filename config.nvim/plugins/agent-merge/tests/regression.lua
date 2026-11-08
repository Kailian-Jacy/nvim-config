-- agent-merge regression suite. Run from anywhere:
--   nvim --clean --headless -l config.nvim/plugins/agent-merge/tests/regression.lua
-- Exits non-zero if any case fails.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.o.swapfile = false
vim.o.hidden = true

local uv = vim.uv or vim.loop
local opts = { load = "manual", confirm_external = true, save_keymap = false, autosave = false }
local am = require("agent-merge")
am.setup(opts)
local monitor, app = require("agent-merge.monitor"), require("agent-merge.app")
local merge, resolver = require("agent-merge.merge"), require("agent-merge.resolver")

local function upv(fn, name)
  for i = 1, 60 do
    local n, v = debug.getupvalue(fn, i)
    if n == nil then return nil end
    if n == name then return v end
  end
end
local pending = upv(app.status, "pending")

-- A real (symlink-free) scratch directory.
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local dir = uv.fs_realpath(tmp)

local failures, current = 0, ""
local function check(cond, what)
  if cond then return end
  failures = failures + 1
  print(("  FAIL [%s] %s"):format(current, what))
end
local function case(name, fn)
  current = name
  local before = failures
  local ok, err = pcall(fn)
  if not ok then failures = failures + 1; print(("  FAIL [%s] error: %s"):format(name, err)) end
  print((failures == before and "PASS  " or "FAIL  ") .. name)
end

local function settle(ms) vim.wait(ms or 50, function() return false end) end
local function lines(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
local function disk(path) return vim.fn.readfile(path) end
local function agent_write(path, l) local f = assert(io.open(path, "w")); f:write(table.concat(l, "\n") .. "\n"); f:close() end
local eq = vim.deep_equal

-- confirm() stub: answers from a queue; `during` simulates the agent writing
-- while the dialog is open.
local dialogs
local function answer(queue, during)
  dialogs = {}
  vim.fn.confirm = function(msg)
    dialogs[#dialogs + 1] = msg
    if during and #dialogs == 1 then during() end
    return table.remove(queue, 1) or 0
  end
end

local n = 0
local function fresh(content, name)
  n = n + 1
  local path = ("%s/%s"):format(dir, name or ("f" .. n .. ".txt"))
  vim.fn.writefile(content, path)
  vim.cmd("silent! tabonly! | silent! only!")
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
  settle(30)
  return vim.api.nvim_get_current_buf(), path
end

------------------------------------------------------------------------------
case("A1 base = written lines; a BufWritePost edit is not lost", function()
  local buf, path = fresh({ "x", "y" })
  local once = true
  local id = vim.api.nvim_create_autocmd("BufWritePost", { buffer = buf, callback = function()
    if once then once = false; vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "late-edit" }) end
  end })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "X" })
  answer({})
  check(app.save(buf), "first save")
  vim.api.nvim_del_autocmd(id)
  check(eq(monitor.base(buf), disk(path)), "base == disk after write")
  check(app.save(buf), "second save")
  check(#dialogs == 0, "no dialog without an agent")
  check(eq(disk(path), { "X", "y", "late-edit" }), "late edit persisted")
end)

case("A2/B5 agent write right after our save is still signalled", function()
  local buf, path = fresh({ "a", "b", "c" })
  agent_write(path, { "a", "b", "c", "agent1" })
  settle(monitor.SETTLE_MS + 200)
  check(pending[buf] and pending[buf].kind == "change", "change pending after agent1")
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "A" })
  answer({ 1 }) -- Merge
  check(app.save(buf), "merge save")
  agent_write(path, { "A", "b", "c", "agent1", "agent2" })
  settle(100)
  check(pending[buf] ~= nil, "external change marked immediately")
  settle(monitor.SETTLE_MS + 200)
  check(pending[buf] and pending[buf].kind == "change", "classified as change")
end)

case("A3 mixed EOL / latin1 / empty files: plain save asks nothing", function()
  for _, spec in ipairs({ { "mixed.txt", "a\r\nb\nc\r\n" }, { "latin1.txt", "caf\233\n" }, { "empty.txt", "" } }) do
    local path = dir .. "/" .. spec[1]
    local f = io.open(path, "wb"); f:write(spec[2]); f:close()
    vim.cmd("edit! " .. path)
    local buf = vim.api.nvim_get_current_buf()
    check(eq(monitor.read_disk(buf, path), monitor.base(buf)), spec[1] .. ": base == read_disk")
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "new" })
    answer({})
    check(app.save(buf), spec[1] .. ": saved")
    check(#dialogs == 0, spec[1] .. ": no fake-merge dialog")
  end
end)

case("A6 merge engine failure is -1, not 255 conflicts", function()
  local path_env = vim.env.PATH
  vim.env.PATH = ""
  local _, c = merge.three_way({ "a" }, { "b" }, { "c" })
  vim.env.PATH = path_env
  check(c == -1, "git unavailable -> -1 (got " .. tostring(c) .. ")")
end)

case("A7 :w through a symlinked path is reconciled", function()
  local link = vim.fn.tempname()
  uv.fs_symlink(dir, link)
  local path = dir .. "/sym.txt"
  vim.fn.writefile({ "l1", "l2", "l3" }, path)
  vim.cmd("edit! " .. link .. "/sym.txt")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "mine3" })
  agent_write(path, { "agent1", "l2", "l3" })
  answer({ 1 }) -- Merge
  vim.cmd("write")
  check(#dialogs == 1, "went through the merge dialog")
  check(eq(disk(path), { "agent1", "l2", "mine3" }), "agent change kept")
  os.remove(link)
end)

------------------------------------------------------------------------------
local function start_conflict()
  local buf, path = fresh({ "l1", "l2", "l3" })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "mine" })
  agent_write(path, { "agent", "l2", "l3" })
  local base = monitor.base(buf)
  answer({ 1 }) -- Resolve
  check(app.save(buf) == false, "resolve does not write")
  check(resolver.active(buf), "resolver open")
  check(eq(monitor.base(buf), base), "base untouched while resolving")
  return buf, path
end

case("B1 closing a resolver window rolls back; save asks again", function()
  local buf, path = start_conflict()
  vim.cmd("close") -- RESULT window
  settle(30)
  check(not resolver.active(buf), "session ended")
  check(eq(lines(buf), { "mine", "l2", "l3" }), "buffer restored to ours")
  check(pending[buf] and pending[buf].kind == "conflict", "still pending [=]")
  answer({ 3 }) -- Abort
  check(app.save(buf) == false, "save after rollback")
  check(#dialogs == 1, "asked again instead of overwriting")
  check(eq(disk(path), { "agent", "l2", "l3" }), "agent change intact")
end)

case("B1 save in the resolver commits the resolution", function()
  local buf, path = start_conflict()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "mine+agent", "l2", "l3" })
  answer({})
  check(app.save(buf), "commit")
  settle(30)
  check(not resolver.active(buf), "session closed")
  check(eq(disk(path), { "mine+agent", "l2", "l3" }), "resolution written")
  check(eq(monitor.base(buf), disk(path)), "base == disk")
  check(pending[buf] == nil, "pending cleared")
end)

case("B1 save with markers left does not write", function()
  local buf, path = start_conflict()
  answer({})
  check(app.save(buf) == false, "refused")
  check(eq(disk(path), { "agent", "l2", "l3" }), "disk untouched")
  resolver.abort(buf)
  settle(30)
end)

case("B1/B3 commit after the agent wrote again re-enters the flow", function()
  local buf, path = start_conflict()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "resolved", "l2", "l3" })
  agent_write(path, { "agent", "l2", "l3", "agent-more" })
  answer({ 1 }) -- Merge (resolution + agent-more)
  check(app.save(buf), "saved after re-confirm")
  check(#dialogs == 1 and dialogs[1]:find("changed on disk again", 1, true) ~= nil, "re-asked with a note")
  check(eq(disk(path), { "resolved", "l2", "l3", "agent-more" }), "only the new agent change merged")
  settle(30)
end)

case("B3 Merge confirmed while the agent writes: re-asked, nothing silent", function()
  local buf, path = fresh({ "l1", "l2", "l3" })
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "mine3" })
  agent_write(path, { "agent1", "l2", "l3" })
  answer({ 1, 3 }, function() agent_write(path, { "agent1", "l2", "agent3" }) end) -- Merge, then Abort
  check(app.save(buf) == false, "not saved")
  check(#dialogs == 2, "second dialog")
  check(dialogs[2] and dialogs[2]:find("conflicting", 1, true) ~= nil, "second dialog is the conflict one")
  check(eq(disk(path), { "agent1", "l2", "agent3" }), "agent content intact")
end)

case("B4 Overwrite confirmed while the agent writes: re-asked", function()
  local buf, path = fresh({ "l1", "l2", "l3" })
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "mine3" })
  agent_write(path, { "agent1", "l2", "l3" })
  answer({ 3, 0 }, function() agent_write(path, { "agent1", "l2", "l3", "agent4" }) end) -- Overwrite, Esc
  check(app.save(buf) == false, "not saved")
  check(#dialogs == 2, "re-asked")
  check(eq(disk(path), { "agent1", "l2", "l3", "agent4" }), "late agent write not discarded")
end)

case("B3 Preview: save writes without a 2nd dialog; undo then save asks", function()
  local buf, path = fresh({ "l1", "l2", "l3" })
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "mine3" })
  agent_write(path, { "agent1", "l2", "l3" })
  answer({ 2 }) -- Preview
  check(app.save(buf) == false, "preview does not write")
  check(eq(lines(buf), { "agent1", "l2", "mine3" }), "merge applied to buffer")
  answer({})
  check(app.save(buf), "save after preview")
  check(#dialogs == 0, "no second dialog")
  check(eq(disk(path), { "agent1", "l2", "mine3" }), "merged written")

  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "mine3b" })
  agent_write(path, { "agentX", "l2", "mine3" })
  answer({ 2 })
  app.save(buf)
  vim.cmd("silent undo")
  answer({ 4 }) -- Cancel
  app.save(buf)
  check(#dialogs == 1, "undo of a preview is asked again")
  check(eq(disk(path), { "agentX", "l2", "mine3" }), "agent change not overwritten")
end)

case("B5 partial agent write: marked, but no fake conflict", function()
  local buf, path = fresh({ "line1", "line2", "line3" })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "MINE" })
  vim.system({ "sh", "-c", "exec 3>" .. path .. "; sleep 0.3; printf 'line1\\nline2\\nline3\\nagent\\n' >&3" })
  settle(120)
  check(pending[buf] and pending[buf].kind == "external", "marked as external (not conflict)")
  settle(300 + monitor.SETTLE_MS + 200)
  check(pending[buf] and pending[buf].kind == "change", "settled as change")
end)

case("B6 :saveas / :file to a new path writes it", function()
  local buf = fresh({ "a" })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "A" })
  answer({})
  vim.cmd("saveas " .. dir .. "/b6-new.txt")
  check(eq(disk(dir .. "/b6-new.txt"), { "A" }), ":saveas wrote")
  check(not vim.bo[buf].modified, ":saveas clean")
  vim.cmd("file " .. dir .. "/b6-file.txt")
  vim.cmd("write")
  check(eq(disk(dir .. "/b6-file.txt"), { "A" }), ":file + :w wrote")
  check(#dialogs == 0, "no dialog for new files")
end)

case("B6 deleted on disk: [x], Recreate/Cancel", function()
  local buf, path = fresh({ "a" })
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "A" })
  os.remove(path)
  settle(monitor.SETTLE_MS + 300)
  check(app.status() == "[x]", "statusline [x] (got " .. app.status() .. ")")
  answer({ 2 }) -- Cancel
  check(app.save(buf) == false and vim.fn.filereadable(path) == 0, "cancel keeps it deleted")
  answer({ 1 }) -- Recreate
  check(app.save(buf) and eq(disk(path), { "A" }), "recreated")
end)

case("B2 triggers: nobuflisted / module re-setup keep a valid base", function()
  local buf, path = fresh({ "a", "b" })
  vim.cmd("setlocal nobuflisted")
  check(eq(monitor.base(buf), { "a", "b" }), "base survives nobuflisted")
  vim.cmd("setlocal buflisted")
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "DIRTY" })
  for k in pairs(package.loaded) do if k:match("^agent%-merge") then package.loaded[k] = nil end end
  require("agent-merge").setup(opts)
  local m2 = require("agent-merge.monitor")
  check(eq(m2.base(buf), { "a", "b" }), "re-setup keeps base (not the dirty buffer)")
  vim.fn.confirm = function() return 0 end
  check(require("agent-merge.app").save(buf), "save")
  check(eq(disk(path), { "DIRTY", "b" }), "user edit not reverted")
end)

print(failures == 0 and "\nALL PASSED" or ("\n" .. failures .. " FAILURE(S)"))
vim.fn.delete(tmp, "rf")
vim.cmd(failures == 0 and "qa!" or "cq!")
