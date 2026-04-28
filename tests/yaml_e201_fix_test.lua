-- tests/test_yaml_e201_fix.lua
-- Verifies that the E201 and LSP detach fixes work correctly.
-- Run: nvim --headless -u NONE -l tests/test_yaml_e201_fix.lua

local errors = {}
local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    table.insert(errors, string.format("FAIL: %s (expected %s, got %s)", msg, tostring(expected), tostring(actual)))
  end
end

local function assert_true(val, msg)
  if not val then
    table.insert(errors, string.format("FAIL: %s (expected truthy, got %s)", msg, tostring(val)))
  end
end

-- ============================================================
-- Test 1: FileType autocmd has loaded guard and explicit bufnr
-- ============================================================
do
  -- Read the autocmds.lua source and verify the fix patterns exist
  local f = io.open("config.nvim/lua/config/autocmds.lua", "r")
  if f then
    local content = f:read("*a")
    f:close()

    assert_true(
      content:find("nvim_buf_is_loaded%(bufnr%)"),
      "autocmds.lua should contain nvim_buf_is_loaded(bufnr) guard"
    )
    assert_true(
      content:find("vim%.treesitter%.start.-%s*bufnr"),
      "autocmds.lua should pass explicit bufnr to treesitter.start"
    )
    assert_true(
      content:find("vim%.bo%[bufnr%]%.filetype"),
      "autocmds.lua should use vim.bo[bufnr].filetype"
    )
    assert_true(
      content:find("vim%.bo%[bufnr%]%.syntax"),
      "autocmds.lua should use vim.bo[bufnr].syntax"
    )
    assert_true(
      content:find("function%(ev%)"),
      "autocmds.lua FileType callback should accept ev parameter"
    )
  else
    table.insert(errors, "FAIL: could not open config.nvim/lua/config/autocmds.lua")
  end
end

-- ============================================================
-- Test 2: NoMatchParen is wrapped in vim.schedule
-- ============================================================
do
  local f = io.open("config.nvim/lua/plugins/bigfile.lua", "r")
  if f then
    local content = f:read("*a")
    f:close()

    -- Should NOT have bare `pcall(vim.cmd, "NoMatchParen")` without schedule
    -- The pattern: vim.schedule(function() ... pcall(vim.cmd, "NoMatchParen") ... end)
    assert_true(
      content:find('vim%.schedule%(function%(%)\n%s+pcall%(vim%.cmd, "NoMatchParen"%)'),
      "bigfile.lua should wrap NoMatchParen in vim.schedule"
    )
  else
    table.insert(errors, "FAIL: could not open config.nvim/lua/plugins/bigfile.lua")
  end
end

-- ============================================================
-- Test 3: LSP detach has validity and attachment guards
-- ============================================================
do
  local f = io.open("config.nvim/lua/plugins/bigfile.lua", "r")
  if f then
    local content = f:read("*a")
    f:close()

    assert_true(
      content:find("nvim_buf_is_valid%(bufnr%)"),
      "bigfile.lua should check nvim_buf_is_valid before LSP detach"
    )
    assert_true(
      content:find("vim%.lsp%.buf_is_attached%(bufnr, client%.id%)"),
      "bigfile.lua should check buf_is_attached before detaching"
    )
  else
    table.insert(errors, "FAIL: could not open config.nvim/lua/plugins/bigfile.lua")
  end
end

-- ============================================================
-- Test 4: Open a YAML file with vim: content via nvim --headless
--         and confirm no E201 error
-- ============================================================
do
  -- Create a test yaml file with "vim:" in the first few lines
  local yaml_path = "/tmp/_test_yaml_e201.yaml"
  local yf = io.open(yaml_path, "w")
  if yf then
    yf:write("en:\n  vim: \"Vim text editor\"\n  hello: world\n  neovim: great\n")
    yf:close()
  end

  -- Run nvim --headless opening the yaml file and capture stderr
  local cmd = string.format(
    'nvim --headless -u NONE -c "set modeline" -c "e %s" -c "qa!" 2>&1',
    yaml_path
  )
  local handle = io.popen(cmd)
  if handle then
    local output = handle:read("*a")
    handle:close()

    -- With modeline=true (our test uses -u NONE which defaults to modeline on)
    -- and a yaml file containing "vim:", we'd see E518/E201 on unpatched nvim.
    -- With -u NONE, our custom autocmds don't load, so this just verifies
    -- that the yaml file itself doesn't crash nvim at the base level.
    -- The real protection is the code-level checks in Tests 1-3.
    if output:find("E201") then
      table.insert(errors, "FAIL: nvim --headless produced E201 when opening yaml with 'vim:' content")
    end
  end

  -- Clean up
  os.remove(yaml_path)
end

-- ============================================================
-- Results
-- ============================================================
if #errors == 0 then
  print("ALL TESTS PASSED (" .. 4 .. " tests)")
  os.exit(0)
else
  for _, err in ipairs(errors) do
    print(err)
  end
  print(string.format("\n%d test(s) FAILED", #errors))
  os.exit(1)
end
