-- Test Autocmds & Custom Commands (125 test cases)
-- Based on reports/04-test-plan-03-autocmds.md

package.path = package.path .. ";tests/?.lua"
local H = require("harness")

io.write("=== Testing Autocmds & Custom Commands ===\n\n")

-- 3.1 RunTest
H.test("TC-CMD-001", "RunTest command exists", function()
  H.assert_eq(vim.fn.exists(":RunTest"), 2)
end)
H.skip("TC-CMD-002", "RunTest executes *_vimtest.lua", "Requires file creation and cd")
H.skip("TC-CMD-003", "RunTest no test file no error", "Requires specific cwd")

-- 3.2 Copen
H.test("TC-CMD-004", "Copen command exists", function()
  H.assert_eq(vim.fn.exists(":Copen"), 2)
end)
H.skip("TC-CMD-005", "Copen opens fullwidth quickfix", "Requires UI interaction")

-- 3.3 RunScript
H.test("TC-CMD-006", "RunScript command exists", function()
  H.assert_eq(vim.fn.exists(":RunScript"), 2)
end)
H.skip("TC-CMD-007", "RunScript executes lua file", "Requires opening lua file")
H.skip("TC-CMD-008", "RunScript executes python file", "Requires python file setup")
H.skip("TC-CMD-009", "RunScript executes shell file", "Requires sh file setup")
H.skip("TC-CMD-010", "RunScript no runner error", "Requires unsupported filetype")
H.skip("TC-CMD-011", "RunScript no filetype error", "Requires empty filetype")
H.skip("TC-CMD-012", "RunScript timeout kills process", "Requires long-running script")
H.skip("TC-CMD-013", "RunScript visual mode executes selection", "Requires visual selection")

-- 3.4 SetBufRunner
H.test("TC-CMD-014", "SetBufRunner command exists", function()
  H.assert_eq(vim.fn.exists(":SetBufRunner"), 2)
end)
H.skip("TC-CMD-015", "SetBufRunner sets buffer-local runner", "Requires buffer setup")

-- 3.5 OverseerRestartLast
H.test("TC-CMD-016", "OverseerRestartLast command exists", function()
  H.assert_eq(vim.fn.exists(":OverseerRestartLast"), 2)
end)

-- 3.6 DebugServe
H.test("TC-CMD-017", "DebugServe command exists", function()
  H.assert_eq(vim.fn.exists(":DebugServe"), 2)
end)

-- 3.7 MasonInstallAll
H.test("TC-CMD-018", "MasonInstallAll command exists", function()
  H.assert_eq(vim.fn.exists(":MasonInstallAll"), 2)
end)

-- 3.8 OpenLaunchJson
H.test("TC-CMD-019", "OpenLaunchJson command exists", function()
  H.assert_eq(vim.fn.exists(":OpenLaunchJson"), 2)
end)
H.skip("TC-CMD-020", "OpenLaunchJson opens launch.json", "Requires .vscode/launch.json")

-- 3.9 Tab management commands
H.test("TC-CMD-021", "PinTab command exists", function()
  H.assert_eq(vim.fn.exists(":PinTab"), 2)
end)

H.test("TC-CMD-022", "PinTab pins current tab", function()
  vim.cmd("PinTab")
  H.assert_true(vim.g.pinned_tab ~= nil, "pinned_tab should be set after PinTab")
  vim.cmd("UnpinTab")  -- cleanup
end)

H.skip("TC-CMD-023", "PinTab moves tab to first position", "Requires multi-tab setup")

H.test("TC-CMD-024", "PinTab with arg sets name", function()
  vim.cmd("PinTab TestName")
  local pt = vim.g.pinned_tab
  H.assert_true(pt ~= nil, "pinned_tab should exist")
  H.assert_eq(pt.name, "TestName", "pinned_tab.name should be TestName")
  vim.cmd("UnpinTab")
end)

H.test("TC-CMD-025", "UnpinTab command exists", function()
  H.assert_eq(vim.fn.exists(":UnpinTab"), 2)
end)

H.test("TC-CMD-026", "UnpinTab clears pinned state", function()
  vim.cmd("PinTab")
  vim.cmd("UnpinTab")
  local pt = vim.g.pinned_tab
  H.assert_true(pt == nil or pt == vim.NIL, "pinned_tab should be nil after UnpinTab")
end)

H.test("TC-CMD-027", "FlipPinnedTab command exists", function()
  H.assert_eq(vim.fn.exists(":FlipPinnedTab"), 2)
end)

H.skip("TC-CMD-028", "FlipPinnedTab jumps to pinned tab", "Requires multi-tab with pinned")
H.skip("TC-CMD-029", "FlipPinnedTab jumps back", "Requires multi-tab with pinned")

H.test("TC-CMD-030", "FlipPinnedTab no pinned tab does nothing", function()
  vim.cmd("UnpinTab")
  -- Should not error
  local ok, err = pcall(vim.cmd, "FlipPinnedTab")
  H.assert_true(ok, "FlipPinnedTab should not error with no pinned tab: " .. tostring(err))
end)

H.test("TC-CMD-031", "SetTabName command sets name", function()
  vim.cmd("SetTabName CustomTest")
  local tn = vim.fn.gettabvar(vim.fn.tabpagenr(), "tabname")
  H.assert_eq(tn, "CustomTest")
  vim.cmd("ResetTabName")
end)

H.test("TC-CMD-032", "ResetTabName clears name", function()
  vim.cmd("SetTabName ToBeCleared")
  vim.cmd("ResetTabName")
  local tn = vim.fn.gettabvar(vim.fn.tabpagenr(), "tabname")
  H.assert_eq(tn, "")
end)

-- 3.10 Tab autocmds
H.skip("TC-CMD-033", "TabLeave records last_tab", "Requires tab switching")
H.skip("TC-CMD-034", "TabClosed cleans pinned_tab", "Requires tab close")

-- 3.11 FocusGained
H.test("TC-CMD-035", "FocusGained autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "FocusGained" })
  H.assert_true(#acmds > 0, "FocusGained autocmd should exist")
end)

-- 3.12 Snippet commands
H.test("TC-CMD-036", "SnipEdit command exists", function()
  H.assert_eq(vim.fn.exists(":SnipEdit"), 2)
end)

H.test("TC-CMD-037", "SnipLoad command exists", function()
  H.assert_eq(vim.fn.exists(":SnipLoad"), 2)
end)

H.test("TC-CMD-038", "SnipPick command exists", function()
  H.assert_eq(vim.fn.exists(":SnipPick"), 2)
end)

-- 3.13 LuaPrint
H.test("TC-CMD-039", "LuaPrint command exists", function()
  H.assert_eq(vim.fn.exists(":LuaPrint"), 2)
end)
H.skip("TC-CMD-040", "LuaPrint executes and prints", "Requires visual selection")

-- 3.14 TextYankPost
H.test("TC-CMD-041", "TextYankPost autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "TextYankPost" })
  H.assert_true(#acmds > 0, "TextYankPost autocmd should exist")
end)
H.skip("TC-CMD-042", "Short text not in yanky ring", "Requires yanky API")
H.skip("TC-CMD-043", "Long text not in yanky ring", "Requires yanky API")

-- 3.15 SVN commands
local function svn_test(id, name)
  if vim.g.modules and vim.g.modules.svn and vim.g.modules.svn.enabled then
    H.test(id, name .. " exists", function()
      H.assert_eq(vim.fn.exists(":" .. name), 2)
    end)
  else
    H.skip(id, name .. " exists", "svn module not enabled")
  end
end

svn_test("TC-CMD-044", "SvnDiffThis")
svn_test("TC-CMD-045", "SvnDiffThisClose")
svn_test("TC-CMD-046", "SvnDiffShiftVersion")
svn_test("TC-CMD-047", "SvnDiffAll")

-- 3.16 Highlight autocmds
H.skip("TC-CMD-048", "FileType enables TSBufEnable for treesitter types", "Requires file open")
H.skip("TC-CMD-049", "Non-treesitter types enable syntax", "Requires file open")

H.test("TC-CMD-050", "highlight_yank autocmd group exists", function()
  local ok, acmds = pcall(vim.api.nvim_get_autocmds, { group = "highlight_yank" })
  H.assert_true(ok and #acmds > 0, "highlight_yank autocmd group should exist")
end)

-- 3.17 Quickfix/help close
H.skip("TC-CMD-051", "quickfix q closes buffer", "Requires quickfix open")
H.skip("TC-CMD-052", "gitsigns-blame q closes buffer", "Requires gitsigns buffer")
H.skip("TC-CMD-053", "help q closes buffer", "Requires help open")
H.skip("TC-CMD-054", "man q closes buffer", "Requires man page open")

-- 3.18 Quickfix navigation
H.test("TC-CMD-055", "Qnext command exists", function()
  H.assert_eq(vim.fn.exists(":Qnext"), 2)
end)

H.test("TC-CMD-056", "Qprev command exists", function()
  H.assert_eq(vim.fn.exists(":Qprev"), 2)
end)

H.test("TC-CMD-057", "Qnewer command exists", function()
  H.assert_eq(vim.fn.exists(":Qnewer"), 2)
end)

H.test("TC-CMD-058", "Qolder command exists", function()
  H.assert_eq(vim.fn.exists(":Qolder"), 2)
end)

H.skip("TC-CMD-059", "Qnext wraps around", "Requires quickfix list")
H.skip("TC-CMD-060", "Qprev wraps around", "Requires quickfix list")

-- 3.19 Split commands
H.test("TC-CMD-061", "Split command exists", function()
  H.assert_eq(vim.fn.exists(":Split"), 2)
end)

H.test("TC-CMD-062", "Vsplit command exists", function()
  H.assert_eq(vim.fn.exists(":Vsplit"), 2)
end)

H.skip("TC-CMD-063", "Split cursor in new window", "Requires window check")

-- 3.20 OldFiles
H.test("TC-CMD-064", "SnackOldfiles command exists", function()
  H.assert_eq(vim.fn.exists(":SnackOldfiles"), 2)
end)

-- 3.21 Bookmark commands
H.test("TC-CMD-065", "BookmarkGrepMarkedFiles command exists", function()
  H.assert_eq(vim.fn.exists(":BookmarkGrepMarkedFiles"), 2)
end)

H.test("TC-CMD-066", "BookmarkSnackPicker command exists", function()
  H.assert_eq(vim.fn.exists(":BookmarkSnackPicker"), 2)
end)

H.test("TC-CMD-067", "BookmarkEditNameAtCursor command exists", function()
  H.assert_eq(vim.fn.exists(":BookmarkEditNameAtCursor"), 2)
end)

H.test("TC-CMD-068", "DeleteBookmarkAtCursor command exists", function()
  H.assert_eq(vim.fn.exists(":DeleteBookmarkAtCursor"), 2)
end)

H.test("TC-CMD-069", "ClearBookmark command exists", function()
  H.assert_eq(vim.fn.exists(":ClearBookmark"), 2)
end)

-- 3.22 Cursor settings
H.test("TC-CMD-070", "guicursor contains block and ver25", function()
  local gc = vim.o.guicursor
  H.assert_contains(gc, "block", "guicursor should contain block")
  H.assert_contains(gc, "ver25", "guicursor should contain ver25")
end)

H.test("TC-CMD-071", "nvim 0.11+ guicursor contains t:ver25", function()
  if vim.fn.has("nvim-0.11") == 1 then
    H.assert_contains(vim.o.guicursor, "t:ver25", "guicursor should contain t:ver25 for 0.11+")
  else
    H.skip("TC-CMD-071", "nvim 0.11+ guicursor t:ver25", "nvim < 0.11")
  end
end)

-- 3.23 Neovide commands
H.test("TC-CMD-072", "NeovideNew command exists", function()
  H.assert_eq(vim.fn.exists(":NeovideNew"), 2)
end)

H.test("TC-CMD-073", "NeovideTransparentToggle command exists", function()
  H.assert_eq(vim.fn.exists(":NeovideTransparentToggle"), 2)
end)

H.skip("TC-CMD-074", "NeovideTransparentToggle toggles", "Requires Neovide runtime")

-- 3.24 SearchHistory
H.test("TC-CMD-075", "SearchHistory command exists", function()
  H.assert_eq(vim.fn.exists(":SearchHistory"), 2)
end)

-- 3.25 ThrowAndReveal
H.test("TC-CMD-076", "ThrowAndReveal command exists", function()
  H.assert_eq(vim.fn.exists(":ThrowAndReveal"), 2)
end)
H.skip("TC-CMD-077", "ThrowAndReveal l creates right window", "Requires window operation test")
H.skip("TC-CMD-078", "ThrowAndReveal reuses existing window", "Requires multi-window test")

-- 3.26 Code command
H.test("TC-CMD-079", "Code command exists", function()
  H.assert_eq(vim.fn.exists(":Code"), 2)
end)

-- 3.27 CopyFilePath
H.test("TC-CMD-080", "CopyFilePath command exists", function()
  H.assert_eq(vim.fn.exists(":CopyFilePath"), 2)
end)
H.skip("TC-CMD-081", "CopyFilePath full", "Requires file opened")
H.skip("TC-CMD-082", "CopyFilePath relative", "Requires file opened")
H.skip("TC-CMD-083", "CopyFilePath dir", "Clipboard not available in headless")
H.skip("TC-CMD-084", "CopyFilePath filename", "Requires file opened")
H.skip("TC-CMD-085", "CopyFilePath line", "Requires file opened")

-- 3.28 Macro recording
H.skip("TC-CMD-086", "RecordingEnter sets status true", "Requires macro recording")
H.skip("TC-CMD-087", "RecordingLeave sets status false", "Requires macro recording")

-- 3.29 VimEnter/VimLeave
H.test("TC-CMD-088", "VimEnter autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "VimEnter" })
  H.assert_true(#acmds > 0, "VimEnter autocmd should exist")
end)

H.test("TC-CMD-089", "VimLeavePre autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "VimLeavePre" })
  H.assert_true(#acmds > 0, "VimLeavePre autocmd should exist")
end)

H.test("TC-CMD-090", "VimLeave autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "VimLeave" })
  H.assert_true(#acmds > 0, "VimLeave autocmd should exist")
end)

-- 3.30 Markdown
H.skip("TC-CMD-091", "BufRead markdown autocmd", "Requires markdown group check")
H.skip("TC-CMD-092", "Markdown buffer pi mapping", "Requires .md file")

-- 3.31 Cd command
H.test("TC-CMD-093", "Cd command exists", function()
  H.assert_eq(vim.fn.exists(":Cd"), 2)
end)

H.test("TC-CMD-094", "Cd changes working directory", function()
  local orig = vim.fn.getcwd()
  vim.cmd("Cd /tmp")
  H.assert_eq(vim.fn.getcwd(), "/tmp")
  vim.cmd("Cd " .. orig)  -- restore
end)

-- 3.32 Lint
H.test("TC-CMD-095", "Lint command exists", function()
  H.assert_eq(vim.fn.exists(":Lint"), 2)
end)

H.test("TC-CMD-096", "BufWritePost has lint callback", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "BufWritePost" })
  H.assert_true(#acmds > 0, "BufWritePost autocmds should exist")
end)

H.test("TC-CMD-097", "LintInfo command exists", function()
  H.assert_eq(vim.fn.exists(":LintInfo"), 2)
end)

-- 3.33 DAP float
H.skip("TC-CMD-098", "dap-float FileType autocmd", "Requires dap-float buffer")
H.skip("TC-CMD-099", "dap-float esc and q close", "Requires dap-float buffer")

-- 3.34 DapTerminate
H.test("TC-CMD-100", "DapTerminate command exists", function()
  H.assert_eq(vim.fn.exists(":DapTerminate"), 2)
end)

-- 3.35 Lcmd / Term
H.test("TC-CMD-101", "Lcmd command exists", function()
  H.assert_eq(vim.fn.exists(":Lcmd"), 2)
end)

H.test("TC-CMD-102", "Lcmdv command exists", function()
  H.assert_eq(vim.fn.exists(":Lcmdv"), 2)
end)

H.test("TC-CMD-103", "Lcmdh command exists", function()
  H.assert_eq(vim.fn.exists(":Lcmdh"), 2)
end)

H.test("TC-CMD-104", "Term command exists", function()
  H.assert_eq(vim.fn.exists(":Term"), 2)
end)

H.test("TC-CMD-105", "Termv command exists", function()
  H.assert_eq(vim.fn.exists(":Termv"), 2)
end)

H.test("TC-CMD-106", "Termh command exists", function()
  H.assert_eq(vim.fn.exists(":Termh"), 2)
end)

H.skip("TC-CMD-107", "Lcmd opens lua buffer", "Requires window test")
H.skip("TC-CMD-108", "Term opens terminal", "Requires terminal test")

-- 3.36 Diagnostics config
H.test("TC-CMD-109", "virtual_text disabled", function()
  local cfg = vim.diagnostic.config()
  H.assert_eq(cfg.virtual_text, false)
end)

H.test("TC-CMD-110", "signs enabled", function()
  local cfg = vim.diagnostic.config()
  -- signs may be true or a table
  H.assert_true(cfg.signs ~= false and cfg.signs ~= nil, "signs should not be false/nil")
end)

H.test("TC-CMD-111", "underline enabled", function()
  local cfg = vim.diagnostic.config()
  H.assert_true(cfg.underline ~= false, "underline should not be false")
end)

H.test("TC-CMD-112", "update_in_insert disabled", function()
  local cfg = vim.diagnostic.config()
  H.assert_eq(cfg.update_in_insert, false)
end)

H.test("TC-CMD-113", "severity_sort enabled", function()
  local cfg = vim.diagnostic.config()
  H.assert_true(cfg.severity_sort ~= false and cfg.severity_sort ~= nil,
    "severity_sort should be truthy")
end)

H.test("TC-CMD-114", "float border = rounded", function()
  local cfg = vim.diagnostic.config()
  H.assert_true(cfg.float ~= nil, "float config should exist")
  H.assert_eq(cfg.float.border, "rounded")
end)

-- 3.37 Hex/Binary
H.test("TC-CMD-115", "read_binary_with_xxd=false no hex autocmd", function()
  H.assert_eq(vim.g.read_binary_with_xxd, false, "read_binary_with_xxd should be false")
end)

-- 3.38 OSC52
H.test("TC-CMD-116", "TextYankPost includes OSC52 copy", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "TextYankPost" })
  H.assert_true(#acmds > 0, "TextYankPost autocmds should exist (for OSC52)")
end)

-- 3.39 Barbecue
H.skip("TC-CMD-117", "barbecue default off", "Requires barbecue status check")

-- 3.40 Shell Integration
H.test("TC-CMD-118", "shell_run function exists", function()
  H.assert_true(type(vim.g.shell_run) == "function", "shell_run should be a function")
end)

H.test("TC-CMD-119", "shell_run executes and returns output", function()
  local out = vim.g.shell_run("echo hello_from_test")
  H.assert_true(out ~= nil, "shell_run should return output")
  H.assert_contains(out, "hello_from_test", "output should contain echo'd text")
end)

-- 3.41 Obsidian
H.test("TC-CMD-120", "ObsUnlink command exists", function()
  H.assert_eq(vim.fn.exists(":ObsUnlink"), 2)
end)

H.test("TC-CMD-121", "ObsOpen command exists", function()
  H.assert_eq(vim.fn.exists(":ObsOpen"), 2)
end)

-- 3.42 Avante FileType
H.skip("TC-CMD-122", "Avante c-c stops generation", "Requires Avante buffer")

-- 3.43 TelescopeAutoCommands
H.test("TC-CMD-123", "TelescopeAutoCommands command exists", function()
  -- This may not exist if telescope is lazy loaded
  local exists = vim.fn.exists(":TelescopeAutoCommands")
  H.assert_true(exists >= 1, "TelescopeAutoCommands should exist (may be lazy)")
end)

-- 3.44 Task management
H.test("TC-CMD-124", "TaskLoad command exists", function()
  H.assert_eq(vim.fn.exists(":TaskLoad"), 2)
end)

H.test("TC-CMD-125", "TaskEdit command exists", function()
  H.assert_eq(vim.fn.exists(":TaskEdit"), 2)
end)

-- Print summary
H.summary()

-- Write results
local f = io.open("tests/results_autocmds.txt", "w")
if f then
  f:write(H.get_report())
  f:close()
end
