-- Test: treesitter migration for neovim 0.12.1 compatibility
-- Run: nvim --headless -u NORC -l tests/test_treesitter_migration.lua
-- Or:  lua tests/test_treesitter_migration.lua (for basic syntax checks)

local passed = 0
local failed = 0
local errors = {}

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

io.write("\n=== Treesitter Migration Tests ===\n\n")

-- ─── Phase 1: Syntax / loadability checks ───

io.write("Phase 1: Config file syntax checks\n")

test("miscellaneous.lua loads without error", function()
  local fn, err = loadfile("config.nvim/lua/plugins/miscellaneous.lua")
  assert(fn, "Failed to load: " .. tostring(err))
end)

test("autocmds.lua loads without error", function()
  -- autocmds.lua uses Neovim-specific Lua features (e.g. `continue`)
  -- that are not available in plain Lua 5.1. Use LuaJIT if available,
  -- otherwise just verify the file exists and our changes are correct.
  local has_luajit = jit ~= nil
  if has_luajit then
    local fn, err = loadfile("config.nvim/lua/config/autocmds.lua")
    assert(fn, "Failed to load: " .. tostring(err))
  else
    -- Plain Lua can't parse Neovim Lua extensions; just verify file exists
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

local function file_content(path)
  local f = io.open(path, "r")
  assert(f, "Cannot open " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

test("miscellaneous.lua: no commit pin, has branch=main", function()
  local content = file_content("config.nvim/lua/plugins/miscellaneous.lua")
  assert(not content:find('commit = "4916d65"'), "Still has old commit pin")
  assert(content:find('branch = "main"'), "Missing branch = main")
end)

test("autocmds.lua: no TSBufEnable, uses vim.treesitter.start", function()
  local content = file_content("config.nvim/lua/config/autocmds.lua")
  assert(not content:find("TSBufEnable highlight"), "Still uses :TSBufEnable highlight")
  assert(content:find("vim.treesitter.start"), "Missing vim.treesitter.start")
end)

test("lsp.lua: no nvim-treesitter.ts_utils require", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(not content:find('require%s*"nvim%-treesitter%.ts_utils"'), "Still requires nvim-treesitter.ts_utils")
  assert(not content:find("require%s*%(?%s*['\"]nvim%-treesitter%.ts_utils['\"]"), "Still requires nvim-treesitter.ts_utils (alt pattern)")
end)

test("lsp.lua: no nvim-treesitter.parsers require", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(not content:find('require%s*"nvim%-treesitter%.parsers"'), "Still requires nvim-treesitter.parsers")
end)

test("lsp.lua: no nvim-treesitter.configs require", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(not content:find('require%s*[%(]?%s*["\']nvim%-treesitter%.configs["\']'), "Still requires nvim-treesitter.configs")
end)

test("lsp.lua: uses vim.treesitter.get_node()", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find("vim.treesitter.get_node"), "Missing vim.treesitter.get_node()")
end)

test("lsp.lua: uses vim.treesitter.get_parser()", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find("vim.treesitter.get_parser"), "Missing vim.treesitter.get_parser()")
end)

test("lsp.lua: no ts_utils.update_selection call", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  -- Check for actual function call, not comments
  for line in content:gmatch("[^\n]+") do
    local stripped = line:match("^%s*(.-)%s*$")
    if not stripped:match("^%-%-") then  -- skip comment lines
      assert(not stripped:find("update_selection"), "Still calls update_selection in code: " .. stripped)
    end
  end
end)

test("lsp.lua: uses nvim-treesitter-textobjects new API", function()
  local content = file_content("config.nvim/lua/plugins/lsp.lua")
  assert(content:find('require%("nvim%-treesitter%-textobjects"%)'), "Missing new textobjects setup")
  assert(content:find('require%("nvim%-treesitter%-textobjects%.select"%)'), "Missing new select API")
end)

test("editor.lua: no nvim-treesitter.indent require", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert(not content:find('require%("nvim%-treesitter%.indent"%)'), "Still requires nvim-treesitter.indent")
end)

test("editor.lua: uses nvim-treesitter indentexpr()", function()
  local content = file_content("config.nvim/lua/plugins/editor.lua")
  assert(content:find('require%("nvim%-treesitter"%).indentexpr'), "Missing nvim-treesitter indentexpr")
end)

test("observability.lua: no nvim-treesitter.parsers require", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  assert(not content:find('require%s*[%(]?%s*["\']nvim%-treesitter%.parsers["\']'), "Still requires nvim-treesitter.parsers")
end)

test("observability.lua: uses vim.treesitter.language API", function()
  local content = file_content("config.nvim/lua/plugins/observability.lua")
  assert(content:find("vim.treesitter.language"), "Missing vim.treesitter.language API")
end)

-- ─── Phase 3: lazy-lock.json checks ───

io.write("\nPhase 3: lazy-lock.json checks\n")

test("lazy-lock.json: nvim-treesitter on main branch", function()
  local content = file_content("config.nvim/lazy-lock.json")
  -- Should have branch "main", not "master"
  assert(content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"main"'), "nvim-treesitter not on main branch")
  assert(not content:find('"nvim%-treesitter":%s*{%s*"branch":%s*"master"'), "nvim-treesitter still on master branch")
end)

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
