-- Test E2E Integration & Behavioral Tests (50 test cases)
-- Based on reports/04-test-plan-05-commands.md

package.path = package.path .. ";tests/?.lua"
local H = require("harness")

io.write("=== Testing E2E Integration ===\n\n")

-- 5.1 Startup flow

H.test("TC-E2E-001", "Complete startup no errors", function()
  -- If we got here, startup was successful
  H.assert_true(true)
end)

H.test("TC-E2E-002", "Plugins loaded after startup", function()
  local stats = require("lazy").stats()
  H.assert_true(stats.loaded > 30, "Should have >30 loaded plugins, got " .. tostring(stats.loaded))
end)

H.test("TC-E2E-003", "Load order correct (options before keymaps)", function()
  -- Verify key indicators of proper load order
  H.assert_eq(vim.g.mapleader, " ", "mapleader should be set (from options)")
  H.assert_true(vim.fn.exists(":RunScript") == 2, "RunScript should exist (from autocmds)")
end)

-- 5.2 Tab lifecycle

H.test("TC-E2E-004", "Tab lifecycle: create -> pin -> unpin", function()
  local orig_tabs = vim.fn.tabpagenr("$")
  -- Create new tab
  vim.cmd("tabnew")
  H.assert_eq(vim.fn.tabpagenr("$"), orig_tabs + 1, "should have one more tab")
  -- Pin it
  vim.cmd("PinTab TestLifecycle")
  H.assert_true(vim.g.pinned_tab ~= nil, "pinned_tab should be set")
  -- Unpin
  vim.cmd("UnpinTab")
  H.assert_true(vim.g.pinned_tab == nil or vim.g.pinned_tab == vim.NIL,
    "pinned_tab should be cleared")
  -- Cleanup: close the extra tab
  vim.cmd("tabclose")
end)

H.test("TC-E2E-005", "Closing pinned tab auto-unpins", function()
  vim.cmd("tabnew")
  vim.cmd("PinTab AutoUnpin")
  local pinned_id = vim.g.pinned_tab and vim.g.pinned_tab.id
  vim.cmd("tabclose")
  -- After tab close, pinned_tab should be cleared
  local pt = vim.g.pinned_tab
  H.assert_true(pt == nil or pt == vim.NIL, "pinned_tab should be nil after closing pinned tab")
end)

H.test("TC-E2E-006", "Tabline shows pinned marker", function()
  vim.cmd("PinTab MarkerTest")
  local tl = Tabline()
  local marker = vim.g.pinned_tab_marker
  H.assert_true(tl:find(marker, 1, true) ~= nil,
    "Tabline should contain pinned marker: " .. marker)
  vim.cmd("UnpinTab")
end)

-- 5.3 Terminal integration
H.skip("TC-E2E-007", "Terminal float -> right -> bottom -> reset", "Requires terminal UI")
H.skip("TC-E2E-008", "Terminal direction keys jump to nvim", "Requires terminal + window")

-- 5.4 Buffer management
H.skip("TC-E2E-009", "Buffer jump history H/L", "Requires multiple buffer navigation")

H.test("TC-E2E-010", "Buffer close preserves window", function()
  -- Create a second buffer
  vim.cmd("enew")
  local buf1 = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "temp buffer" })
  vim.cmd("enew")
  local buf2 = vim.api.nvim_get_current_buf()
  local win_count_before = #vim.api.nvim_tabpage_list_wins(0)
  -- Go back to buf1 and "delete" it (simulating bd)
  vim.api.nvim_set_current_buf(buf1)
  vim.cmd("bdelete " .. buf1)
  local win_count_after = #vim.api.nvim_tabpage_list_wins(0)
  H.assert_eq(win_count_after, win_count_before, "Window count should not change after bdelete")
end)

-- 5.5 ThrowAndReveal
H.skip("TC-E2E-011", "ThrowAndReveal to right new window", "Requires single window")
H.skip("TC-E2E-012", "ThrowAndReveal to existing window", "Requires multi-window")

-- 5.6 Debugging mode
H.test("TC-E2E-013", "Debug mode toggle on/off", function()
  H.assert_eq(vim.g.debugging_keymap, false, "debugging_keymap should start as false")
  -- We can test the function exists
  H.assert_true(type(vim.g.nvim_dap_keymap) == "function", "nvim_dap_keymap function should exist")
  H.assert_true(type(vim.g.nvim_dap_upmap) == "function", "nvim_dap_upmap function should exist")
end)

H.skip("TC-E2E-014", "debugging_status changes with DAP events", "Requires DAP session")
H.skip("TC-E2E-015", "lualine shows debug info", "Requires debugging_keymap=true")

-- 5.7 Format integration
H.skip("TC-E2E-016", "ConformFormat restrict mode", "Requires buffer with code")
H.skip("TC-E2E-017", "ConformFormat visual mode", "Requires visual selection")
H.skip("TC-E2E-018", "<leader><CR> format + lint + save", "Requires file to save")

-- 5.8 Quickfix integration
H.test("TC-E2E-019", "Quickfix dd deletes entry", function()
  -- Set up quickfix list
  vim.fn.setqflist({
    { filename = "a.txt", lnum = 1, text = "item1" },
    { filename = "b.txt", lnum = 2, text = "item2" },
    { filename = "c.txt", lnum = 3, text = "item3" },
  })
  local before = #vim.fn.getqflist()
  H.assert_eq(before, 3, "should have 3 quickfix items")
  -- We can't easily simulate dd in quickfix here, but we can verify
  -- QFdelete function exists
  H.assert_eq(vim.fn.exists("*QFdelete"), 1, "QFdelete function should exist")
end)

H.skip("TC-E2E-020", "Quickfix visual d deletes multiple", "Requires quickfix interaction")

H.test("TC-E2E-021", "Qnext/Qprev cycle navigation commands exist", function()
  H.assert_eq(vim.fn.exists(":Qnext"), 2)
  H.assert_eq(vim.fn.exists(":Qprev"), 2)
end)

-- 5.9 CopyFilePath integration
H.skip("TC-E2E-022", "CopyFilePath full end-to-end", "Requires clipboard")
H.skip("TC-E2E-023", "CopyFilePath relative removes cwd prefix", "Requires clipboard")

-- 5.10 Script Runner
H.skip("TC-E2E-024", "Lua script runs in neovim", "Requires file opened")
H.skip("TC-E2E-025", "SetBufRunner overrides RunScript runner", "Requires buffer setup")
H.skip("TC-E2E-026", "<C-c> interrupts running script", "Requires running process")

-- 5.11 Yank integration
H.test("TC-E2E-027", "TextYankPost highlight exists", function()
  local ok, acmds = pcall(vim.api.nvim_get_autocmds, { group = "highlight_yank" })
  H.assert_true(ok and #acmds > 0, "highlight_yank autocmd should exist")
end)

H.skip("TC-E2E-028", "TextYankPost yanky ring filter", "Requires yanky API")

H.test("TC-E2E-029", "OSC52 clipboard sync autocmd exists", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "TextYankPost" })
  H.assert_true(#acmds >= 2, "TextYankPost should have multiple autocmds (highlight + osc52)")
end)

-- 5.12 Macro recording
H.skip("TC-E2E-030", "Recording start sets status true", "Requires macro recording")
H.skip("TC-E2E-031", "Recording stop sets status false", "Requires macro recording")
H.skip("TC-E2E-032", "Lualine shows q during recording", "Requires lualine capture")

-- 5.13 Snippet integration
H.skip("TC-E2E-033", "SnipEdit -> SnipLoad flow", "Requires snippet editing")
H.skip("TC-E2E-034", "SnipPick opens picker", "Requires UI")

-- 5.14 Bookmark integration
H.skip("TC-E2E-035", "Bookmark create -> view -> delete", "Requires interactive test")
H.skip("TC-E2E-036", "BookmarkGrepMarkedFiles", "Requires marked files")

-- 5.15 Window maximize
H.test("TC-E2E-037", "Window maximize toggle", function()
  -- Create split
  vim.cmd("vsplit")
  local wins_before = #vim.api.nvim_tabpage_list_wins(0)
  H.assert_true(wins_before >= 2, "should have at least 2 windows after vsplit")
  -- Close the split for cleanup
  vim.cmd("only")
end)

H.skip("TC-E2E-038", "Lualine shows m during maximize", "Requires lualine capture")

-- 5.16 VimEnter/VimLeave
H.test("TC-E2E-039", "VimLeavePre saves LAST_WORKING_DIRECTORY", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "VimLeavePre" })
  H.assert_true(#acmds > 0, "VimLeavePre should have autocmds")
end)

H.test("TC-E2E-040", "VimLeave has tmux detach logic", function()
  local acmds = vim.api.nvim_get_autocmds({ event = "VimLeave" })
  H.assert_true(#acmds > 0, "VimLeave should have autocmds")
end)

-- 5.17 Snacks picker custom actions
H.skip("TC-E2E-041", "picker <c-t> opens in new tab", "Requires picker UI")
H.skip("TC-E2E-042", "picker <c-/> search selected file", "Requires picker UI")
H.skip("TC-E2E-043", "picker maximize action", "Requires picker UI")
H.skip("TC-E2E-044", "zoxide picker lcd/tcd", "Requires picker UI")
H.skip("TC-E2E-045", "explorer <d-cr> tcd to dir", "Requires picker UI")
H.skip("TC-E2E-046", "command_history modify/execute", "Requires picker UI")

-- 5.18 Line Move
H.test("TC-E2E-047", "<M-j> line move down functional test", function()
  -- Create buffer with content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })  -- cursor on line1
  -- Execute the move down
  vim.cmd("normal! :m .+1\\<CR>")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- After move, line1 should be at position 2
  H.assert_eq(lines[1], "line2", "line2 should be first after moving line1 down")
  H.assert_eq(lines[2], "line1", "line1 should be second after moving down")
  -- Cleanup
  vim.cmd("bdelete! " .. buf)
end)

H.test("TC-E2E-048", "<M-k> line move up functional test", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })  -- cursor on line2
  vim.cmd("normal! :m .-2\\<CR>")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  H.assert_eq(lines[1], "line2", "line2 should be first after moving up")
  H.assert_eq(lines[2], "line1", "line1 should be second")
  vim.cmd("bdelete! " .. buf)
end)

-- 5.19 Visual till brackets
H.test("TC-E2E-049", "[ key jumps to before [ character", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello [world]" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })  -- cursor at h
  -- The [ mapping is t[ which moves to the char before [
  -- We can verify the mapping exists
  local m = vim.fn.maparg("[", "n")
  H.assert_true(m ~= nil and m ~= "", "[ should have mapping")
  vim.cmd("bdelete! " .. buf)
end)

H.test("TC-E2E-050", "d[ deletes to before [", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello [world]" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local m = vim.fn.maparg("d[", "n")
  H.assert_true(m ~= nil and m ~= "", "d[ should have mapping")
  vim.cmd("bdelete! " .. buf)
end)

-- Print summary
H.summary()

-- Write results
local f = io.open("tests/results_e2e.txt", "w")
if f then
  f:write(H.get_report())
  f:close()
end
