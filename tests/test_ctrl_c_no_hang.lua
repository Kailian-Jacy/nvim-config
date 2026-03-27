-- Test for Issue #50: NeoVim Hangs on Terminal C-c
--
-- Statically verifies that the feedkeys recursion anti-pattern that caused
-- infinite loops (and froze Neovim) is not present in the codebase.
--
-- Run: nvim --headless +"luafile tests/test_ctrl_c_no_hang.lua"
-- Results written to /tmp/test_ctrl_c_results.txt
--
-- What this tests:
--   1. No terminal-mode <C-c> mapping using feedkeys with "t" flag (the hang pattern)
--   2. keymaps.lua C-c fallback uses nvim_replace_termcodes (not raw literal)
--   3. dap-repl C-c mapping is still present in repl.lua

local results_file = "/tmp/test_ctrl_c_results.txt"
local f = io.open(results_file, "w")
local passed = 0
local failed = 0

local function log(msg)
  f:write(msg .. "\n")
  f:flush()
end

local function assert_test(name, condition, msg)
  if condition then
    log("  PASS: " .. name)
    passed = passed + 1
  else
    log("  FAIL: " .. name .. (msg and (" - " .. msg) or ""))
    failed = failed + 1
  end
end

--- Read a file and return its contents as a string
local function read_file(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local content = fh:read("*a")
  fh:close()
  return content
end

log("=== Issue #50: Terminal C-c Hang Prevention Tests ===")
log("")

-- Locate source files relative to this test
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local repo_root = test_dir:gsub("tests/$", "")
local repl_lua = repo_root .. "config.nvim/lua/plugins/repl.lua"
local keymaps_lua = repo_root .. "config.nvim/lua/config/keymaps.lua"

-- ============================================================
-- Test 1: repl.lua must NOT have a TermOpen autocmd that maps
--         <C-c> in terminal mode with feedkeys("t") flag
-- ============================================================
log("[Test 1] No terminal-mode C-c feedkeys recursion in repl.lua")

local repl_content = read_file(repl_lua)
assert_test(
  "repl.lua is readable",
  repl_content ~= nil,
  "Could not read " .. repl_lua
)

if repl_content then
  -- Check that the dangerous TermOpen + feedkeys("t") pattern is absent.
  -- We look for the specific anti-pattern: a TermOpen autocmd body containing
  -- feedkeys with the "t" flag for <C-c>.
  local has_termopen_cc = repl_content:find('nvim_create_autocmd%("TermOpen"') ~= nil
    and repl_content:find('feedkeys%(keys,%s*"t"') ~= nil
  assert_test(
    "No TermOpen autocmd with feedkeys('t') for C-c",
    not has_termopen_cc,
    "Found the dangerous TermOpen + feedkeys('t') pattern that causes infinite recursion"
  )

  -- Also verify no terminal-mode keymap.set with "t" mode and feedkeys "t" flag
  -- (a more general check for the anti-pattern)
  local has_tmode_feedkeys_t = false
  -- Split into lines and scan for the pattern within TermOpen blocks
  for line in repl_content:gmatch("[^\n]+") do
    if line:find('keymap%.set%("t"') and line:find('feedkeys') then
      has_tmode_feedkeys_t = true
      break
    end
  end
  assert_test(
    "No terminal-mode keymap using feedkeys (general check)",
    not has_tmode_feedkeys_t,
    "Found a terminal-mode keymap that uses feedkeys — potential recursion risk"
  )
end

-- ============================================================
-- Test 2: keymaps.lua C-c fallback must use nvim_replace_termcodes
--         and must NOT use raw literal "<C-c>" with feedkeys "t"
-- ============================================================
log("")
log("[Test 2] keymaps.lua C-c fallback correctness")

local keymaps_content = read_file(keymaps_lua)
assert_test(
  "keymaps.lua is readable",
  keymaps_content ~= nil,
  "Could not read " .. keymaps_lua
)

if keymaps_content then
  -- The broken pattern was: vim.api.nvim_feedkeys("<C-c>", "t", false)
  -- This feeds a literal 5-char string "<C-c>" instead of the actual termcode.
  local has_literal_cc_feedkeys = keymaps_content:find('feedkeys%("<%C%-c>"') ~= nil
  assert_test(
    "No literal '<C-c>' string passed to feedkeys",
    not has_literal_cc_feedkeys,
    "Found feedkeys with literal '<C-c>' — should use nvim_replace_termcodes first"
  )

  -- The fix should use nvim_replace_termcodes for the C-c fallback
  local has_termcodes_cc = keymaps_content:find('replace_termcodes%("<%C%-c>"') ~= nil
  assert_test(
    "C-c fallback uses nvim_replace_termcodes",
    has_termcodes_cc,
    "The C-c interrupt fallback should convert termcodes before feeding keys"
  )

  -- The fix should use "n" flag (noremap) instead of "t" to prevent recursion
  -- Find the C-c keymap section and check its feedkeys flag
  local cc_section = keymaps_content:match('Interrupt code runner.-feedkeys%(.-%).-end')
  if cc_section then
    local uses_n_flag = cc_section:find('"n"') ~= nil
    assert_test(
      "C-c fallback feedkeys uses 'n' (noremap) flag",
      uses_n_flag,
      "Should use 'n' flag to prevent mapping recursion"
    )
  else
    assert_test(
      "C-c interrupt keymap section found",
      false,
      "Could not locate the C-c interrupt keymap section in keymaps.lua"
    )
  end
end

-- ============================================================
-- Test 3: dap-repl C-c mapping must still be present
-- ============================================================
log("")
log("[Test 3] dap-repl C-c mapping preserved")

if repl_content then
  -- The dap-repl FileType autocmd with C-c mapping should still exist
  local has_daprepl_autocmd = repl_content:find('pattern%s*=%s*{%s*"dap%-repl"%s*}') ~= nil
  assert_test(
    "dap-repl FileType autocmd exists",
    has_daprepl_autocmd,
    "The dap-repl FileType autocmd should still be present"
  )

  -- The dap-repl C-c mapping should use "i" mode (insert), not "t" (terminal)
  -- and should clear the line, not use feedkeys with "t" flag
  local has_daprepl_cc = repl_content:find('Clear current REPL input line') ~= nil
    or repl_content:find('Clear the current input line') ~= nil
  assert_test(
    "dap-repl C-c mapping for clearing input exists",
    has_daprepl_cc,
    "The dap-repl insert-mode C-c mapping should still be present"
  )

  -- dap-repl C-c should use "n" flag in feedkeys (for Esc fallback), not "t"
  -- Find the dap-repl section
  local daprepl_section = repl_content:match('dap%-repl.-Clear current REPL input line')
    or repl_content:match('dap%-repl.-clear the current input')
  if daprepl_section then
    local daprepl_uses_safe_feedkeys = daprepl_section:find('"n"') ~= nil
    assert_test(
      "dap-repl C-c uses safe 'n' flag in feedkeys",
      daprepl_uses_safe_feedkeys,
      "dap-repl feedkeys should use 'n' flag"
    )
  end
end

-- Summary
log("")
log(string.format("=== Results: %d passed, %d failed ===", passed, failed))
f:close()

-- Print to stdout as well for headless runs
print(string.format("Issue #50 tests: %d passed, %d failed", passed, failed))
local results = read_file(results_file)
if results then print(results) end

if failed > 0 then
  vim.cmd("cq!")  -- exit with error code
else
  vim.cmd("qa!")
end
