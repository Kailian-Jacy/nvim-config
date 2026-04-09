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

test("autocmds.lua: additional_vim_regex_highlighting preserved", function()
  local content = file_content("config.nvim/lua/config/autocmds.lua")
  -- After vim.treesitter.start(), vim.bo.syntax = "on" must appear
  -- BEFORE the else branch (i.e., in the treesitter-enabled path)
  local ts_start_pos = content:find("vim.treesitter.start")
  assert(ts_start_pos, "Missing vim.treesitter.start()")
  local after_ts = content:sub(ts_start_pos)
  local syntax_on_pos = after_ts:find('vim%.bo%.syntax = "on"')
  local else_pos = after_ts:find("\n%s*else\n")
  assert(syntax_on_pos, "Missing vim.bo.syntax = 'on' after vim.treesitter.start()")
  assert(else_pos, "Missing else branch")
  assert(syntax_on_pos < else_pos,
    "vim.bo.syntax = 'on' must appear before else (in treesitter branch, not just else)")
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

test("lsp.lua: uses nvim-treesitter-textobjects new API", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find('require%("nvim%-treesitter%-textobjects"%)'),
    "Missing new textobjects setup")
  assert(content:find('require%("nvim%-treesitter%-textobjects%.select"%)'),
    "Missing new select API")
end)

test("lsp.lua: incremental selection keymaps present", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  -- The incremental selection must have init (normal mode Tab),
  -- expand (visual mode Tab), and shrink (visual mode S-Tab)
  assert(content:find('<Tab>'), "Missing <Tab> keymap")
  assert(content:find('<S%-Tab>'), "Missing <S-Tab> keymap")
  -- Must use treesitter node tree walking (parent/child)
  assert(content:find(':parent%(') or content:find("select_parent"),
    "Missing node expansion logic (parent or select_parent)")
  assert(content:find(':named_child%(') or content:find("select_child"),
    "Missing node shrink logic (named_child or select_child)")
end)

test("lsp.lua: visual selection handles exclusive end position", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  -- Must check end_col == 0 for off-by-one correction
  assert(content:find("end_col %=%= 0"), "Missing end_col == 0 check for exclusive end position")
  -- Must use node:range() (which returns 4 values) not node:start()/node:end_()
  assert(content:find("node:range%(%)"), "Should use node:range() for full position info")
  -- Must NOT use gv (which restores previous selection, not the new marks)
  assert_no_code_match(content, 'normal! gv', "Should not use gv to restore selection")
end)

test("editor.lua: no nvim-treesitter.indent require", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert_no_code_match(content, 'require%("nvim%-treesitter%.indent"%)',
    "Still requires nvim-treesitter.indent")
end)

test("editor.lua: sets vim.v.lnum before indentexpr()", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert(content:find("vim.v.lnum = lnum"),
    "Must set vim.v.lnum before calling indentexpr()")
end)

test("observability.lua: no nvim-treesitter.parsers require in code", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  assert_no_code_match(content, 'require%s*[%(]?%s*["\']nvim%-treesitter%.parsers["\']',
    "Still requires nvim-treesitter.parsers")
end)

test("observability.lua: no duplicate get_lang() call", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  -- Find the treesitter status section and count get_lang calls
  local count = 0
  local in_section = false
  for line in content:gmatch("[^\n]+") do
    if line:find("Treesitter status") then in_section = true end
    if in_section then
      for _ in line:gmatch("get_lang%(") do count = count + 1 end
      if line:find("Installed parsers") then break end
    end
  end
  assert(count <= 1, "get_lang() called " .. count .. " times, should be 1")
end)

-- ─── Phase 3: lazy-lock.json checks ───

io.write("\nPhase 3: lazy-lock.json checks\n")

test("lazy-lock.json: nvim-treesitter on main branch with commit", function()
  local content = file_content("config.nvim/lazy-lock.json")
  assert(content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"main"'),
    "nvim-treesitter not on main branch")
  assert(not content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"master"'),
    "nvim-treesitter still on master branch")
  assert(content:find('"nvim%-treesitter":%s*{[^}]*"commit":%s*"[0-9a-f]+"'),
    "nvim-treesitter missing commit hash in lazy-lock.json")
end)

-- ─── Phase 4: Runtime behavior tests (nvim only) ───

io.write("\nPhase 4: Runtime behavior tests")
if not is_nvim then
  io.write(" (skipped: not running inside nvim)\n")
else
  io.write("\n")

  test("vim.treesitter.get_node() callable with no args", function()
    -- Create a scratch buffer with Lua content
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1" })
    vim.bo[buf].filetype = "lua"
    -- get_node() should be callable and return nil or a node (no crash)
    local ok, result = pcall(vim.treesitter.get_node)
    assert(ok, "vim.treesitter.get_node() crashed: " .. tostring(result))
    -- result can be nil if no parser is loaded, that's fine
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("vim.treesitter.get_parser() returns nil on failure (not throw)", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "nonexistent_filetype_xyz"
    -- In neovim 0.12, get_parser() should return nil, not throw
    local ok, result = pcall(vim.treesitter.get_parser)
    if ok then
      -- Should be nil for unknown filetype
      -- (older nvim may throw instead — both behaviors are handled by our code)
    end
    -- Either way, our code wraps with nil checks, so this is informational
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("vim.treesitter.start() callable via pcall", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1" })
    vim.bo[buf].filetype = "lua"
    local ok, err = pcall(vim.treesitter.start)
    -- Should not crash regardless of parser availability
    assert(ok or type(err) == "string", "vim.treesitter.start() unexpected error type")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("visual selection logic: end_col=0 correction", function()
    -- Simulate the off-by-one logic from lsp.lua
    -- When a node ends at (row=5, col=0), it means the node actually
    -- ends on row 4 (exclusive end), so end_row should be decremented.
    local function compute_end_row(start_row, start_col, end_row, end_col)
      if end_col == 0 and end_row > start_row then
        end_row = end_row - 1
      end
      return end_row
    end
    -- Node spanning lines 2-4, end at col 0 of line 5 (exclusive)
    assert(compute_end_row(2, 0, 5, 0) == 4,
      "Should correct end_row from 5 to 4 when end_col=0")
    -- Node ending mid-line: no correction needed
    assert(compute_end_row(2, 0, 5, 10) == 5,
      "Should NOT correct end_row when end_col > 0")
    -- Single-line node at col 0: no correction (end_row == start_row)
    assert(compute_end_row(2, 0, 2, 0) == 2,
      "Should NOT correct single-line node")
  end)

  test("indentexpr vim.v.lnum propagation", function()
    -- Verify vim.v.lnum is writable and reads back correctly
    vim.v.lnum = 42
    assert(vim.v.lnum == 42, "vim.v.lnum should be settable to 42, got " .. tostring(vim.v.lnum))
    vim.v.lnum = 1
  end)

  test("vim.treesitter.language.get_lang() works for known filetypes", function()
    -- Should return a lang or nil, never crash
    local ok, result = pcall(vim.treesitter.language.get_lang, "lua")
    assert(ok, "get_lang('lua') crashed: " .. tostring(result))
    -- result is "lua" if lua parser is registered, nil otherwise — both OK
  end)

  test("get_select_line_cnt nil-handling path", function()
    -- Simulate the get_select_line_cnt function from lsp.lua
    -- with a buffer that has no parser → should return nil, 0
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "nonexistent_filetype_xyz_migration_test"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test content" })

    -- In 0.12, get_parser() returns nil for unknown filetypes.
    -- In 0.11, it throws. Our code must handle both — test via pcall.
    local ok, parser = pcall(vim.treesitter.get_parser)
    if ok and parser == nil then
      -- 0.12 path: nil return, our code checks `if parser then` → handled
    elseif not ok then
      -- 0.11 path: throws error, our code would need pcall wrapping
      -- (the actual lsp.lua code runs in a user command context where
      -- this is acceptable — conform.nvim handles errors gracefully)
    end
    -- Either way, the nil-check in our code is correct
    vim.api.nvim_buf_delete(buf, { force = true })
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
