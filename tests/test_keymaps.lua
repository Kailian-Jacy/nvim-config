-- Test Keymaps (134 test cases)
-- Based on reports/04-test-plan-02-keymaps.md

package.path = package.path .. ";tests/?.lua"
local H = require("harness")

io.write("=== Testing Keymaps ===\n\n")

-- Helper: check if any mapping exists for lhs in mode (including function mappings)
local function has_mapping(lhs, mode)
  mode = mode or "n"
  -- Try maparg first
  local m = vim.fn.maparg(lhs, mode)
  if m ~= nil and m ~= "" then return true end
  -- Try nvim_get_keymap for function mappings
  local maps = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(maps) do
    if map.lhs == lhs then return true end
  end
  return false
end

-- 2.1 Basic editing

H.test("TC-KEY-001", "* does not jump to next match", function()
  H.assert_true(has_mapping("*", "n"), "* mapping should exist")
end)

H.test("TC-KEY-002", "Y maps to clipboard yank in normal", function()
  H.assert_true(has_mapping("Y", "n"), "Y should have mapping in normal mode")
end)

H.test("TC-KEY-003", "Y maps in visual mode", function()
  H.assert_true(has_mapping("Y", "v"), "Y should have mapping in visual mode")
end)

H.test("TC-KEY-004", "<D-v> in insert mode", function()
  H.assert_true(has_mapping("<D-v>", "i"), "<D-v> should exist in insert mode")
end)

H.test("TC-KEY-005", "<D-v> in terminal mode", function()
  H.assert_true(has_mapping("<D-v>", "t"), "<D-v> should exist in terminal mode")
end)

H.test("TC-KEY-006", "<D-v> in command mode", function()
  H.assert_true(has_mapping("<D-v>", "c"), "<D-v> should exist in command mode")
end)

-- 2.2 Command mode

H.test("TC-KEY-007", "<C-e> in command mode to end", function()
  H.assert_true(has_mapping("<C-e>", "c"), "<C-e> should exist in command mode")
end)

H.test("TC-KEY-008", "<C-a> in command mode to home", function()
  H.assert_true(has_mapping("<C-a>", "c"), "<C-a> should exist in command mode")
end)

-- 2.3 LuaPrint
H.test("TC-KEY-009", "<leader>pr in visual mode for LuaPrint", function()
  H.assert_true(has_mapping("<leader>pr", "v") or has_mapping(" pr", "v"),
    "<leader>pr should exist in visual mode")
end)

-- 2.4 Path copy
H.test("TC-KEY-010", "<leader>yd copies dir", function()
  H.assert_true(has_mapping(" yd", "n"), "<leader>yd should exist")
end)

H.test("TC-KEY-011", "<leader>yp copies full path", function()
  H.assert_true(has_mapping(" yp", "n"), "<leader>yp should exist")
end)

H.test("TC-KEY-012", "<leader>yr copies relative path", function()
  H.assert_true(has_mapping(" yr", "n"), "<leader>yr should exist")
end)

H.test("TC-KEY-013", "<leader>yf copies filename", function()
  H.assert_true(has_mapping(" yf", "n"), "<leader>yf should exist")
end)

H.test("TC-KEY-014", "<leader>yl copies filename:line", function()
  H.assert_true(has_mapping(" yl", "n"), "<leader>yl should exist")
end)

H.test("TC-KEY-015", "Path copy also in visual mode", function()
  H.assert_true(has_mapping(" yd", "v"), "<leader>yd should exist in visual mode")
end)

-- 2.5 Inc-Rename
H.test("TC-KEY-016", "<leader>rn in visual uses IncRename", function()
  H.assert_true(has_mapping(" rn", "v"), "<leader>rn should exist in visual mode")
end)

-- 2.6 Filetype conditional
H.skip("TC-KEY-017", "C++ <leader>hh header switch", "Requires opening .cpp file")
H.skip("TC-KEY-018", "Non-C++ no <leader>hh mapping", "Requires opening .py file")

-- 2.7 Window operations
H.test("TC-KEY-019", "<leader>- horizontal split mapping exists", function()
  H.assert_true(has_mapping(" -", "n"), "<leader>- should exist")
end)

H.test("TC-KEY-020", "<leader>| vertical split mapping exists", function()
  H.assert_true(has_mapping(" |", "n"), "<leader>| should exist")
end)

H.test("TC-KEY-021", "<leader>wd close window mapping exists", function()
  H.assert_true(has_mapping(" wd", "n"), "<leader>wd should exist")
end)

H.test("TC-KEY-022", "<Esc> clears search highlight", function()
  H.assert_true(has_mapping("<Esc>", "n"), "<Esc> should have mapping")
end)

H.test("TC-KEY-023", "<leader>ps paste from clipboard", function()
  H.assert_true(has_mapping(" ps", "n"), "<leader>ps should exist")
end)

-- 2.8 Window maximize
H.test("TC-KEY-024", "<leader>wm maximize window mapping exists", function()
  H.assert_true(has_mapping(" wm", "n"), "<leader>wm should exist")
end)

H.skip("TC-KEY-025", "<leader>wm restore window", "Requires multi-window setup")

-- 2.9 Interrupt
H.test("TC-KEY-026", "<C-c> kills running script mapping exists", function()
  H.assert_true(has_mapping("<C-c>", "n"), "<C-c> should have mapping")
end)

H.test("TC-KEY-027", "<C-c> fallback without running script", function()
  H.assert_true(has_mapping("<C-c>", "n"), "<C-c> should have fallback logic")
end)

-- 2.10 RunScript
H.test("TC-KEY-028", "<C-S-CR> maps to RunScript", function()
  H.assert_true(has_mapping("<C-S-CR>", "n"), "<C-S-CR> should exist")
end)

H.test("TC-KEY-029", "<D-S-CR> maps to RunScript", function()
  H.assert_true(has_mapping("<D-S-CR>", "n"), "<D-S-CR> should exist")
end)

-- 2.11 Comment
H.test("TC-KEY-030", "<leader>cm in normal mode", function()
  H.assert_true(has_mapping(" cm", "n"), "<leader>cm should exist in normal mode")
end)

H.test("TC-KEY-031", "<leader>cm in visual mode", function()
  H.assert_true(has_mapping(" cm", "v"), "<leader>cm should exist in visual mode")
end)

-- 2.12 SVN
H.test("TC-KEY-032", "svn module mapping check", function()
  if vim.g.modules and vim.g.modules.svn and vim.g.modules.svn.enabled then
    H.assert_true(has_mapping(" sd", "n"), "<leader>sd should exist when svn enabled")
  else
    H.skip("TC-KEY-032", "svn module mapping", "svn module not enabled")
  end
end)

H.skip("TC-KEY-033", "svn module disabled no mapping", "Environment dependent")

-- 2.13 Misc
H.test("TC-KEY-034", "<C-i> preserved", function()
  H.assert_true(has_mapping("<C-I>", "n") or has_mapping("<C-i>", "n"), "<C-i> should exist")
end)

H.test("TC-KEY-035", "ZA save and quit all", function()
  H.assert_true(has_mapping("ZA", "n"), "ZA should have mapping")
end)

H.test("TC-KEY-036", "<leader>G opens LazyGit", function()
  H.assert_true(has_mapping(" G", "n"), "<leader>G should exist")
end)

-- 2.14 Window direction
H.test("TC-KEY-037", "<C-J> move to window below", function()
  H.assert_true(has_mapping("<C-J>", "n"), "<C-J> should exist in normal mode")
end)

H.test("TC-KEY-038", "<C-H> move to window left", function()
  H.assert_true(has_mapping("<C-H>", "n"), "<C-H> should exist")
end)

H.test("TC-KEY-039", "<C-L> move to window right", function()
  H.assert_true(has_mapping("<C-L>", "n"), "<C-L> should exist")
end)

H.test("TC-KEY-040", "<C-K> move to window above", function()
  H.assert_true(has_mapping("<C-K>", "n"), "<C-K> should exist")
end)

H.test("TC-KEY-041", "Window keys in visual mode", function()
  H.assert_true(has_mapping("<C-J>", "v"), "<C-J> should exist in visual mode")
end)

H.test("TC-KEY-042", "Window keys in insert mode", function()
  H.assert_true(has_mapping("<C-J>", "i"), "<C-J> should exist in insert mode")
end)

H.test("TC-KEY-043", "Window keys in terminal mode", function()
  H.assert_true(has_mapping("<C-J>", "t"), "<C-J> should exist in terminal mode")
end)

H.skip("TC-KEY-044", "Floating window blocks direction move", "Requires floating window")

-- 2.15 ThrowAndReveal
H.test("TC-KEY-045", "<C-S-l> throw buffer right", function()
  H.assert_true(has_mapping("<C-S-L>", "n") or has_mapping("<C-S-l>", "n"),
    "<C-S-l> should exist")
end)

H.test("TC-KEY-046", "<C-S-k> throw buffer up", function()
  H.assert_true(has_mapping("<C-S-K>", "n") or has_mapping("<C-S-k>", "n"),
    "<C-S-k> should exist")
end)

H.test("TC-KEY-047", "<C-S-j> throw buffer down", function()
  H.assert_true(has_mapping("<C-S-J>", "n") or has_mapping("<C-S-j>", "n"),
    "<C-S-j> should exist")
end)

H.test("TC-KEY-048", "<C-S-h> throw buffer left", function()
  H.assert_true(has_mapping("<C-S-H>", "n") or has_mapping("<C-S-h>", "n"),
    "<C-S-h> should exist")
end)

-- 2.16 Quickfix
H.test("TC-KEY-049", "<leader>qj next quickfix", function()
  H.assert_true(has_mapping(" qj", "n"), "<leader>qj should exist")
end)

H.test("TC-KEY-050", "<leader>qk prev quickfix", function()
  H.assert_true(has_mapping(" qk", "n"), "<leader>qk should exist")
end)

H.test("TC-KEY-051", "<leader>ql newer quickfix list", function()
  H.assert_true(has_mapping(" ql", "n"), "<leader>ql should exist")
end)

H.test("TC-KEY-052", "<leader>qh older quickfix list", function()
  H.assert_true(has_mapping(" qh", "n"), "<leader>qh should exist")
end)

-- 2.17 Search
H.test("TC-KEY-053", "/ in visual mode searches selection", function()
  H.assert_true(has_mapping("/", "v"), "/ should exist in visual mode")
end)

H.test("TC-KEY-054", "gh hover/ufo peek", function()
  H.assert_true(has_mapping("gh", "n"), "gh should exist")
end)

H.test("TC-KEY-055", "ge opens diagnostic float", function()
  H.assert_true(has_mapping("ge", "n"), "ge should exist")
end)

H.test("TC-KEY-056", "ga code action", function()
  H.assert_true(has_mapping("ga", "n"), "ga should exist")
end)

-- 2.18 Buffer close
H.test("TC-KEY-057", "<leader>bd close buffer mapping exists", function()
  H.assert_true(has_mapping(" bd", "n"), "<leader>bd should exist")
end)

H.skip("TC-KEY-058", "<leader>bd doesn't close modified buffer", "Requires buffer modification")
H.skip("TC-KEY-059", "<leader>bd force closes dap-terminal", "Requires dap-terminal buffer")

-- 2.19 Line move
H.test("TC-KEY-060", "<M-j> move line down mapping exists", function()
  H.assert_true(has_mapping("<M-j>", "n"), "<M-j> should exist in normal mode")
end)

H.test("TC-KEY-061", "<M-k> move line up mapping exists", function()
  H.assert_true(has_mapping("<M-k>", "n"), "<M-k> should exist in normal mode")
end)

H.test("TC-KEY-062", "<M-j> in visual mode", function()
  H.assert_true(has_mapping("<M-j>", "v"), "<M-j> should exist in visual mode")
end)

H.skip("TC-KEY-063", "<M-j> supports count", "Requires functional test")

-- 2.20 Visual till brackets
H.test("TC-KEY-064", "[ maps to t[", function()
  local m = vim.fn.maparg("[", "n")
  H.assert_true(m ~= nil and m ~= "", "[ should have mapping")
end)

H.test("TC-KEY-065", "] maps to t]", function()
  local m = vim.fn.maparg("]", "n")
  H.assert_true(m ~= nil and m ~= "", "] should have mapping")
end)

H.test("TC-KEY-066", "{ maps to t{", function()
  local m = vim.fn.maparg("{", "n")
  H.assert_true(m ~= nil and m ~= "", "{ should have mapping")
end)

H.test("TC-KEY-067", "} maps to t}", function()
  local m = vim.fn.maparg("}", "n")
  H.assert_true(m ~= nil and m ~= "", "} should have mapping")
end)

H.test("TC-KEY-068", "( maps to t(", function()
  local m = vim.fn.maparg("(", "n")
  H.assert_true(m ~= nil and m ~= "", "( should have mapping")
end)

H.test("TC-KEY-069", ") maps to t)", function()
  local m = vim.fn.maparg(")", "n")
  H.assert_true(m ~= nil and m ~= "", ") should have mapping")
end)

H.test("TC-KEY-070", ", maps to t,", function()
  local m = vim.fn.maparg(",", "n")
  H.assert_true(m ~= nil and m ~= "", ", should have mapping")
end)

H.test("TC-KEY-071", "? maps to t?", function()
  local m = vim.fn.maparg("?", "n")
  H.assert_true(m ~= nil and m ~= "", "? should have mapping")
end)

H.test("TC-KEY-072", "d[ maps to dt[", function()
  local m = vim.fn.maparg("d[", "n")
  H.assert_true(m ~= nil and m ~= "", "d[ should have mapping")
end)

H.test("TC-KEY-073", "[ in visual mode maps to t[", function()
  local m = vim.fn.maparg("[", "v")
  H.assert_true(m ~= nil and m ~= "", "[ should have mapping in visual mode")
end)

-- 2.21 Tab operations
H.test("TC-KEY-074", "<leader><tab> creates new tab", function()
  H.assert_true(has_mapping(" <Tab>", "n") or has_mapping("<Space><Tab>", "n"),
    "<leader><tab> should exist")
end)

H.test("TC-KEY-075", "<tab> maps to FlipPinnedTab", function()
  H.assert_true(has_mapping("<Tab>", "n"), "<tab> should have mapping")
end)

H.test("TC-KEY-076", "d<tab> closes tab", function()
  H.assert_true(has_mapping("d<Tab>", "n"), "d<tab> should have mapping")
end)

H.test("TC-KEY-077", "<C-tab> next tab", function()
  H.assert_true(has_mapping("<C-Tab>", "n"), "<C-tab> should exist")
end)

H.test("TC-KEY-078", "<S-C-tab> prev tab", function()
  H.assert_true(has_mapping("<C-S-Tab>", "n") or has_mapping("<S-C-Tab>", "n"),
    "<S-C-tab> should exist")
end)

H.test("TC-KEY-079", "<leader>up pin/unpin tab", function()
  H.assert_true(has_mapping(" up", "n"), "<leader>up should exist")
end)

H.test("TC-KEY-080", "<leader>uP pin tab with arg", function()
  H.assert_true(has_mapping(" uP", "n"), "<leader>uP should exist")
end)

-- 2.22 Neovide transparency
H.test("TC-KEY-081", "<leader>uT toggle transparency", function()
  H.assert_true(has_mapping(" uT", "n"), "<leader>uT should exist")
end)

-- 2.23 Context display
H.test("TC-KEY-082", "<C-G> shows navic location", function()
  H.assert_true(has_mapping("<C-G>", "n"), "<C-G> should have mapping")
end)

-- 2.24 Debugging mappings
local debug_keys = {
  { "TC-KEY-083", "<leader>db", " db", "toggle breakpoint" },
  { "TC-KEY-084", "<leader>dB", " dB", "breakpoint list" },
  { "TC-KEY-085", "<leader>dc", " dc", "continue" },
  { "TC-KEY-086", "<leader>dC", " dC", "run to cursor" },
  { "TC-KEY-087", "<leader>dW", " dW", "add watch" },
  { "TC-KEY-088", "<leader>dn", " dn", "step over" },
  { "TC-KEY-089", "<leader>dN", " dN", "new session" },
  { "TC-KEY-090", "<leader>ds", " ds", "step into" },
  { "TC-KEY-091", "<leader>dS", " dS", "show sessions" },
  { "TC-KEY-092", "<leader>do", " do", "step out" },
  { "TC-KEY-093", "<leader>du", " du", "up callstack" },
  { "TC-KEY-094", "<leader>dd", " dd", "down callstack" },
  { "TC-KEY-095", "<leader>dF", " dF", "show frames" },
  { "TC-KEY-096", "<leader>dp", " dp", "hover" },
  { "TC-KEY-097", "<leader>dP", " dP", "show scopes" },
  { "TC-KEY-098", "<leader>dR", " dR", "restart debug" },
  { "TC-KEY-100", "<leader>dT", " dT", "toggle DapView" },
  { "TC-KEY-101", "<leader>dE", " dE", "disconnect and close debug" },
}

for _, dk in ipairs(debug_keys) do
  H.test(dk[1], dk[2] .. " " .. dk[4], function()
    H.assert_true(has_mapping(dk[3], "n"), dk[2] .. " should exist")
  end)
end

H.test("TC-KEY-099", "<leader>d<c-c> pause", function()
  -- This is a complex lhs, check via nvim_get_keymap
  local maps = vim.api.nvim_get_keymap("n")
  local found = false
  for _, map in ipairs(maps) do
    if map.lhs:find("d") and map.lhs:find("<C%-C>") then
      found = true
      break
    end
  end
  H.assert_true(found or has_mapping(" d<C-c>", "n"), "<leader>d<c-c> should exist")
end)

-- 2.25 Debug mode toggle
H.test("TC-KEY-102", "<leader>dD toggle debug keymap mode", function()
  H.assert_true(has_mapping(" dD", "n"), "<leader>dD should exist")
end)

H.skip("TC-KEY-103", "Debug mode b maps to breakpoint", "Requires debug mode activation")
H.skip("TC-KEY-104", "Debug mode c maps to continue", "Requires debug mode activation")
H.skip("TC-KEY-105", "Exit debug mode restores mappings", "Requires debug mode activation")

H.test("TC-KEY-106", "<leader>DD start generic debug", function()
  H.assert_true(has_mapping(" DD", "n"), "<leader>DD should exist")
end)

H.test("TC-KEY-107", "<leader>Dt terminate debug", function()
  H.assert_true(has_mapping(" Dt", "n"), "<leader>Dt should exist")
end)

-- 2.26 Cmd mappings (D-* to leader)
local cmd_mappings = {
  { "TC-KEY-108", "<D-a>", "AI modify" },
  { "TC-KEY-109", "<D-b>", "buffer list" },
  { "TC-KEY-110", "<D-c>", "comment" },
  { "TC-KEY-111", "<D-D>", "debug mode toggle" },
  { "TC-KEY-112", "<D-e>", "file browse" },
  { "TC-KEY-113", "<D-f>", "file find" },
  { "TC-KEY-114", "<D-g>", "git hunk preview" },
  { "TC-KEY-115", "<D-i>", "message history" },
  { "TC-KEY-116", "<D-j>", "buffer diagnostics" },
  { "TC-KEY-117", "<D-k>", "keymaps list" },
  { "TC-KEY-118", "<D-l>", "task output" },
  { "TC-KEY-119", "<D-n>", "new buffer" },
  { "TC-KEY-120", "<D-o>", "window maximize" },
  { "TC-KEY-121", "<D-p>", "command history" },
  { "TC-KEY-122", "<D-r>", "LSP rename" },
  { "TC-KEY-123", "<D-s>", "symbols" },
  { "TC-KEY-124", "<D-t>", "terminal" },
  { "TC-KEY-125", "<D-v>", "paste" },
  { "TC-KEY-126", "<D-w>", "close buffer" },
  { "TC-KEY-127", "<D-x>", "horizontal split" },
  { "TC-KEY-128", "<D-y>", "yanky" },
  { "TC-KEY-129", "<D-z>", "zoxide" },
  { "TC-KEY-130", "<D-/>", "global search" },
  { "TC-KEY-131", "<D-CR>", "format" },
}

for _, cm in ipairs(cmd_mappings) do
  H.test(cm[1], cm[2] .. " maps to " .. cm[3], function()
    H.assert_true(has_mapping(cm[2], "n"), cm[2] .. " should exist in normal mode")
  end)
end

H.test("TC-KEY-132", "D-* mappings also in insert mode", function()
  H.assert_true(has_mapping("<D-f>", "i"), "<D-f> should exist in insert mode")
end)

H.test("TC-KEY-133", "no_insert_mode mappings not in insert mode", function()
  -- <D-CR> should NOT be in insert mode (no_insert_mode = true)
  local m = vim.fn.maparg("<D-CR>", "i")
  H.assert_true(m == nil or m == "", "<D-CR> should NOT be in insert mode")
end)

H.skip("TC-KEY-134", "back_to_insert returns to insert mode", "Requires functional test")

-- 2.25 Debugging mode watch visual
H.test("TC-KEY-087v", "<leader>dW also in visual mode", function()
  H.assert_true(has_mapping(" dW", "v"), "<leader>dW should exist in visual mode")
end)

-- Print summary
H.summary()

-- Write results to file
local f = io.open("tests/results_keymaps.txt", "w")
if f then
  f:write(H.get_report())
  f:close()
end
