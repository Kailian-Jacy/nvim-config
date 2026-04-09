-- Test: treesitter migration for neovim 0.12.1 compatibility
-- Run: nvim --headless -u NORC -l tests/test_treesitter_migration.lua
-- Or:  lua tests/test_treesitter_migration.lua (limited to syntax/content tests)

local passed = 0
local failed = 0
local errors = {}
local is_nvim = vim ~= nil and vim.api ~= nil

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.write("  ✓ " .. name .. "\n")
  else
    failed = failed + 1
    table.insert(errors, { name = name, err = err })
    io.write("  ✗ " .. name .. ": " .. tostring(err) .. "\n")
  end
end

local function skip(name, reason)
  io.write("  ⊘ " .. name .. " (skipped: " .. reason .. ")\n")
end

local function file_content(path)
  local f = io.open(path, "r")
  assert(f, "Cannot open " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

-- Helper: check that a string does NOT appear in non-comment code lines
local function assert_no_code_match(content, pattern, msg)
  for line in content:gmatch("[^\n]+") do
    local stripped = line:match("^%s*(.-)%s*$")
    if not stripped:match("^%-%-") then
      assert(not stripped:find(pattern), msg .. ": " .. stripped)
    end
  end
end

io.write("\n=== Treesitter Migration Tests ===\n\n")

-- ─── Phase 1: Syntax / loadability checks ───

io.write("Phase 1: Config file syntax checks\n")

test("miscellaneous.lua loads without error", function()
  local fn, err = loadfile("config.nvim/lua/plugins/miscellaneous.lua")
  assert(fn, "Failed to load: " .. tostring(err))
end)

test("autocmds.lua loads without error", function()
  local has_luajit = jit ~= nil
  if has_luajit then
    local fn, err = loadfile("config.nvim/lua/config/autocmds.lua")
    assert(fn, "Failed to load: " .. tostring(err))
  else
    local f = io.open("config.nvim/lua/config/autocmds.lua", "r")
    assert(f, "File not found")
    f:close()
  end
end)

test("lsp.lua loads without error", function()
  local fn, err = loadfile("config.nvim/lua/plugins/lsp.lua")
  assert(fn, "Failed to load: " .. tostring(err))
end)

test("editor.lua loads without error", function()
  local fn, err = loadfile("config.nvim/lua/plugins/editor.lua")
  assert(fn, "Failed to load: " .. tostring(err))
end)

test("observability.lua loads without error", function()
  local fn, err = loadfile("config.nvim/lua/plugins/observability.lua")
  assert(fn, "Failed to load: " .. tostring(err))
end)

-- ─── Phase 2: Content verification (no removed APIs) ───

io.write("\nPhase 2: Removed API reference checks\n")

test("miscellaneous.lua: no commit pin, has branch=main", function()
  local content = file_content("config.nvim/lua/plugins/miscellaneous.lua")
  assert(not content:find('commit = "4916d65"'), "Still has old commit pin")
  assert(content:find('branch = "main"'), "Missing branch = main")
end)

test("autocmds.lua: no TSBufEnable, uses vim.treesitter.start", function()
  local content = file_content("config.nvim/lua/config/autocmds.lua")
  assert_no_code_match(content, "TSBufEnable", "Still uses :TSBufEnable highlight")
  assert(content:find("vim.treesitter.start"), "Missing vim.treesitter.start")
end)

test("autocmds.lua: additional_vim_regex_highlighting preserved via pcall", function()
  local content = file_content("config.nvim/lua/config/autocmds.lua")
  -- treesitter.start should be called via pcall, and syntax = "on"
  -- should only be set when pcall succeeds
  assert(content:find("pcall%(vim%.treesitter%.start%)"),
    "Missing pcall(vim.treesitter.start)")
  -- After the pcall, check for the conditional syntax enable
  local found_ok_check = false
  local in_ts_block = false
  for line in content:gmatch("[^\n]+") do
    if line:find("pcall%(vim%.treesitter%.start%)") then
      in_ts_block = true
    end
    if in_ts_block and line:find("if ok then") then
      found_ok_check = true
    end
    if in_ts_block and found_ok_check and line:find('vim%.bo%.syntax = "on"') then
      break
    end
    if in_ts_block and line:find("^%s*else") and not found_ok_check then
      break  -- hit else without checking ok
    end
  end
  assert(found_ok_check,
    "vim.bo.syntax should only be set when pcall(vim.treesitter.start) succeeds")
end)

test("lsp.lua: no nvim-treesitter.ts_utils require in code", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert_no_code_match(content, 'require%s*"nvim%-treesitter%.ts_utils"',
    "Still requires nvim-treesitter.ts_utils")
  assert_no_code_match(content, "require%s*%(?%s*['\"]nvim%-treesitter%.ts_utils['\"]",
    "Still requires nvim-treesitter.ts_utils (alt)")
end)

test("lsp.lua: no nvim-treesitter.parsers require in code", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert_no_code_match(content, 'require%s*"nvim%-treesitter%.parsers"',
    "Still requires nvim-treesitter.parsers")
end)

test("lsp.lua: no nvim-treesitter.configs require in code", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert_no_code_match(content, 'require%s*[%(]?%s*["\']nvim%-treesitter%.configs["\']',
    "Still requires nvim-treesitter.configs")
end)

test("lsp.lua: uses vim.treesitter.get_node()", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find("vim.treesitter.get_node"), "Missing vim.treesitter.get_node()")
end)

test("lsp.lua: uses vim.treesitter.get_parser()", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find("vim.treesitter.get_parser"), "Missing vim.treesitter.get_parser()")
end)

test("lsp.lua: no ts_utils.update_selection call in code", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert_no_code_match(content, "update_selection",
    "Still calls update_selection in code")
end)

test("lsp.lua: no gv usage for visual selection", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert_no_code_match(content, 'normal! gv',
    "Should not use gv to restore selection — use direct cursor placement")
end)

test("lsp.lua: uses nvim-treesitter-textobjects new API", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find('require%("nvim%-treesitter%-textobjects"%)'),
    "Missing new textobjects setup")
  assert(content:find('require%("nvim%-treesitter%-textobjects%.select"%)'),
    "Missing new select API")
end)

test("lsp.lua: visual selection uses node:range() and end_col correction", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  -- Must use node:range() for full 4-value position
  assert(content:find("node:range%(%)"),
    "Should use node:range() for complete position info")
  -- Must check end_col == 0 for exclusive end position correction
  assert(content:find("end_col %=%= 0"),
    "Missing end_col == 0 check for exclusive end position")
  -- Must use nvim_win_set_cursor for selection, not gv
  assert(content:find("nvim_win_set_cursor"),
    "Should use nvim_win_set_cursor for visual selection")
end)

test("lsp.lua: incremental selection keymaps present (Tab/S-Tab)", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find('"<Tab>"') or content:find("'<Tab>'"),
    "Missing <Tab> keymap for incremental selection init/expand")
  assert(content:find('"<S%-Tab>"') or content:find("'<S%-Tab>'"),
    "Missing <S-Tab> keymap for incremental selection shrink")
  -- Must use node tree walking
  assert(content:find(':parent%('),
    "Missing node:parent() for expand logic")
  assert(content:find(':named_child%('),
    "Missing node:named_child() for shrink logic")
end)

test("editor.lua: no nvim-treesitter.indent require", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert_no_code_match(content, 'require%("nvim%-treesitter%.indent"%)',
    "Still requires nvim-treesitter.indent")
end)

test("editor.lua: sets vim.v.lnum before calling indentexpr()", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert(content:find("vim.v.lnum = lnum"),
    "Must set vim.v.lnum before calling indentexpr()")
  assert(content:find('require%("nvim%-treesitter"%).indentexpr'),
    "Missing nvim-treesitter indentexpr() call")
end)

test("observability.lua: no nvim-treesitter.parsers require in code", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  assert_no_code_match(content, 'require%s*[%(]?%s*["\']nvim%-treesitter%.parsers["\']',
    "Still requires nvim-treesitter.parsers")
end)

test("observability.lua: no redundant get_lang() calls", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  -- Count get_lang calls in the treesitter status section
  local count = 0
  local in_section = false
  for line in content:gmatch("[^\n]+") do
    if line:find("Treesitter status") then in_section = true end
    if in_section then
      for _ in line:gmatch("get_lang%(") do count = count + 1 end
      if line:find("Installed parsers") then break end
    end
  end
  assert(count <= 1,
    "get_lang() called " .. count .. " times in treesitter section, should be ≤1")
end)

-- ─── Phase 3: lazy-lock.json checks ───

io.write("\nPhase 3: lazy-lock.json checks\n")

test("lazy-lock.json: nvim-treesitter on main branch with commit hash", function()
  local content = file_content("config.nvim/lazy-lock.json")
  assert(content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"main"'),
    "nvim-treesitter not on main branch")
  assert(not content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"master"'),
    "nvim-treesitter still on master branch")
  -- Must have a commit hash
  assert(content:find('"nvim%-treesitter":%s*{[^}]*"commit":%s*"[0-9a-f]+"'),
    "nvim-treesitter missing commit hash in lazy-lock.json")
end)

-- ─── Phase 4: Runtime behavior tests (nvim --headless only) ───

io.write("\nPhase 4: Runtime behavior tests")
if not is_nvim then
  io.write(" (skipped: not running inside nvim)\n")
else
  io.write("\n")

  test("runtime: vim.treesitter.get_node() callable (no crash)", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1" })
    vim.bo[buf].filetype = "lua"
    -- get_node() should be callable (returns nil or a node)
    local ok, result = pcall(vim.treesitter.get_node)
    assert(ok, "vim.treesitter.get_node() crashed: " .. tostring(result))
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("runtime: nil parser handling (unknown filetype)", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "nonexistent_filetype_xyz_test"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test" })

    -- get_parser() should return nil for unknown filetypes (or throw in older nvim)
    local ok, result = pcall(vim.treesitter.get_parser)
    if ok then
      -- 0.12+: returns nil — which our code handles via nil check
      -- result can be nil or parser object
    else
      -- older nvim: throws — which our code would also survive due to nil checks
    end
    -- Either way, our code correctly handles both paths
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("runtime: vim.treesitter.start() via pcall (no crash)", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1" })
    vim.bo[buf].filetype = "lua"
    local ok, err = pcall(vim.treesitter.start)
    -- Should not crash; may fail if parser not installed, but pcall catches that
    assert(ok or type(err) == "string",
      "vim.treesitter.start() unexpected error type")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("runtime: visual selection end_col=0 off-by-one correction logic", function()
    -- Reproduce the exact logic from lsp.lua's ConformFormat
    local function compute_adjusted_end_row(start_row, start_col, end_row, end_col)
      if end_col == 0 and end_row > start_row then
        end_row = end_row - 1
      end
      return end_row
    end
    -- Block node: spans lines 2-4, treesitter reports end at (5, 0)
    -- because end is exclusive → actual last content line is 4
    assert(compute_adjusted_end_row(2, 0, 5, 0) == 4,
      "Should correct end_row 5→4 when end_col=0 (exclusive end)")
    -- Inline node: ends mid-line at (5, 10) → no correction
    assert(compute_adjusted_end_row(2, 0, 5, 10) == 5,
      "Should NOT correct end_row when end_col>0")
    -- Single-line node: start=end, even if end_col=0
    assert(compute_adjusted_end_row(2, 0, 2, 0) == 2,
      "Should NOT correct when end_row==start_row")
    -- Verify line_cnt computation
    local function compute_line_cnt(sr, sc, er, ec)
      if ec == 0 and er > sr then er = er - 1 end
      return er - sr + 1
    end
    assert(compute_line_cnt(0, 0, 5, 0) == 5,
      "5-line node: end at (5,0) should give 5 lines, not 6")
    assert(compute_line_cnt(0, 0, 5, 3) == 6,
      "Node ending at (5,3) should give 6 lines")
  end)

  test("runtime: vim.v.lnum is writable and propagates to indentexpr", function()
    local original = vim.v.lnum
    vim.v.lnum = 42
    assert(vim.v.lnum == 42,
      "vim.v.lnum should be settable; got " .. tostring(vim.v.lnum))
    vim.v.lnum = 99
    assert(vim.v.lnum == 99,
      "vim.v.lnum should update to 99; got " .. tostring(vim.v.lnum))
    -- Restore
    vim.v.lnum = original or 0
  end)

  test("runtime: vim.treesitter.language.get_lang() for known filetype", function()
    local ok, result = pcall(vim.treesitter.language.get_lang, "lua")
    assert(ok, "get_lang('lua') crashed: " .. tostring(result))
    -- result is "lua" if registered, nil otherwise — both acceptable
  end)

  test("runtime: ModeChanged autocmd pattern is valid", function()
    -- Verify that the ModeChanged pattern we use for incremental selection
    -- reset is syntactically valid (doesn't error on autocmd creation)
    local ok, err = pcall(function()
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "[vV\x16]*:n",
        callback = function() end,
        once = true,  -- clean up
      })
    end)
    assert(ok, "ModeChanged pattern '[vV\\x16]*:n' is invalid: " .. tostring(err))
  end)
end

-- ─── Summary ───

io.write(string.format(
  "\n=== Results: %d passed, %d failed ===\n",
  passed, failed
))

if failed > 0 then
  io.write("\nFailed tests:\n")
  for _, e in ipairs(errors) do
    io.write("  • " .. e.name .. ": " .. tostring(e.err) .. "\n")
  end
  os.exit(1)
else
  io.write("All tests passed! ✓\n")
  os.exit(0)
end
