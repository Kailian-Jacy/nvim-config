-- Test: treesitter compatibility shims for neovim 0.12+
-- Run: nvim --headless -u NORC -l tests/test_treesitter_compat_shims.lua

-- ─── Version gate ───────────────────────────────────────────────────────────
-- The shims are only installed on Neovim 0.12+.  On earlier versions almost
-- every test would fail because the shim early-returns an empty table and
-- package.preload entries are never registered.  Skip gracefully.
local version = vim.version()
if version.major == 0 and version.minor < 12 then
  io.write("\n=== Treesitter Compat Shim Tests ===\n")
  io.write(string.format(
    "  ⏭  Skipping: Neovim %d.%d (shims only apply to 0.12+)\n\n",
    version.major, version.minor
  ))
  io.write("=== Results: 0 passed, 0 failed (skipped) ===\n\n")
  os.exit(0)
end

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

io.write("\n=== Treesitter Compat Shim Tests ===\n\n")

-- Load the compat module
io.write("Phase 1: Shim loading\n")

test("treesitter-compat module loads", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(compat, "treesitter-compat module should return a table")
  assert(type(compat._installed) == "table", "_installed should be a table")
end)

io.write("\nPhase 2: Shim module requires don't error\n")

local shim_modules = {
  "nvim-treesitter.configs",
  "nvim-treesitter.parsers",
  "nvim-treesitter.ts_utils",
  "nvim-treesitter.locals",
  "nvim-treesitter.indent",
  "nvim-treesitter.highlight",
  "nvim-treesitter.textobjects",
  "nvim-treesitter.query",
  "nvim-treesitter.utils",
  "nvim-treesitter.info",
}

-- Load shims first
dofile("config.nvim/lua/config/treesitter-compat.lua")

for _, mod_name in ipairs(shim_modules) do
  test("require('" .. mod_name .. "') succeeds", function()
    local ok, mod = pcall(require, mod_name)
    assert(ok, "require failed: " .. tostring(mod))
    assert(type(mod) == "table", "module should return a table, got " .. type(mod))
  end)
end

io.write("\nPhase 3: Shim API functionality\n")

test("nvim-treesitter.configs.setup() is callable", function()
  local configs = require("nvim-treesitter.configs")
  configs.setup({ highlight = { enable = true } }) -- no-op, should not error
end)

test("nvim-treesitter.configs.get_module() returns table", function()
  local configs = require("nvim-treesitter.configs")
  local mod = configs.get_module("highlight")
  assert(type(mod) == "table", "get_module should return a table")
end)

test("nvim-treesitter.parsers.has_parser() is callable", function()
  local parsers = require("nvim-treesitter.parsers")
  local result = parsers.has_parser("lua")
  assert(type(result) == "boolean", "has_parser should return boolean")
end)

test("nvim-treesitter.parsers.get_parser_configs() returns table", function()
  local parsers = require("nvim-treesitter.parsers")
  local configs = parsers.get_parser_configs()
  assert(type(configs) == "table", "get_parser_configs should return table")
end)

test("nvim-treesitter.parsers.ft_to_lang() works", function()
  local parsers = require("nvim-treesitter.parsers")
  local lang = parsers.ft_to_lang("lua")
  assert(type(lang) == "string", "ft_to_lang should return string")
end)

test("nvim-treesitter.ts_utils.get_node_text() delegates to vim.treesitter", function()
  local ts_utils = require("nvim-treesitter.ts_utils")
  assert(type(ts_utils.get_node_text) == "function", "get_node_text should be a function")
end)

test("nvim-treesitter.ts_utils unknown function returns no-op", function()
  local ts_utils = require("nvim-treesitter.ts_utils")
  local fn = ts_utils.some_nonexistent_function
  assert(type(fn) == "function", "unknown function should return a function stub")
  fn() -- should not error
end)

test("nvim-treesitter.locals functions return empty tables", function()
  local locals = require("nvim-treesitter.locals")
  local defs = locals.get_definitions(0)
  assert(type(defs) == "table", "get_definitions should return table")
  local refs = locals.get_references(0)
  assert(type(refs) == "table", "get_references should return table")
end)

test("nvim-treesitter.locals unknown function returns stub", function()
  local locals = require("nvim-treesitter.locals")
  local fn = locals.some_nonexistent_function
  assert(type(fn) == "function", "unknown function should return a function stub")
end)

test("nvim-treesitter.indent functions are callable", function()
  local indent = require("nvim-treesitter.indent")
  indent.attach(0)
  indent.detach(0)
  local result = indent.get_indent(1)
  assert(result == -1, "get_indent should return -1")
end)

test("nvim-treesitter.highlight functions are callable", function()
  local hl = require("nvim-treesitter.highlight")
  hl.attach(0, "lua")
  hl.detach(0)
end)

-- ── New tests for missing shim modules (go.nvim compat) ──

test("nvim-treesitter.query.iter_prepared_matches() returns iterator", function()
  local ts_query = require("nvim-treesitter.query")
  local iter = ts_query.iter_prepared_matches(nil, nil, 0, 0, 0)
  assert(type(iter) == "function", "iter_prepared_matches should return a function (iterator)")
  -- Iterator should immediately return nil (empty)
  assert(iter() == nil, "empty iterator should return nil on first call")
end)

test("nvim-treesitter.query unknown function returns no-op", function()
  local ts_query = require("nvim-treesitter.query")
  local fn = ts_query.some_nonexistent_function
  assert(type(fn) == "function", "unknown function should return a function stub")
  fn() -- should not error
end)

test("nvim-treesitter.utils is a valid table with fallback", function()
  local utils = require("nvim-treesitter.utils")
  assert(type(utils) == "table", "utils should be a table")
  -- Any unknown key should return a no-op function
  local fn = utils.some_nonexistent_function
  assert(type(fn) == "function", "unknown function should return a function stub")
  fn() -- should not error
end)

test("nvim-treesitter.info.installed_parsers() returns table", function()
  local info = require("nvim-treesitter.info")
  local parsers = info.installed_parsers()
  assert(type(parsers) == "table", "installed_parsers should return a table")
end)

test("nvim-treesitter.info unknown function returns stub", function()
  local info = require("nvim-treesitter.info")
  local fn = info.some_nonexistent_function
  assert(type(fn) == "function", "unknown function should return a function stub")
end)

io.write("\nPhase 4: Config file syntax checks\n")

test("treesitter-compat.lua syntax is valid", function()
  local fn, err = loadfile("config.nvim/lua/config/treesitter-compat.lua")
  assert(fn, "Syntax error: " .. tostring(err))
end)

test("init.lua syntax is valid", function()
  local fn, err = loadfile("config.nvim/init.lua")
  assert(fn, "Syntax error: " .. tostring(err))
end)

io.write("\nPhase 5: Structural checks\n")

test("M._installed is always initialised (not nil)", function()
  -- Force a fresh load
  package.loaded["config.treesitter-compat"] = nil
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(type(compat._installed) == "table",
    "_installed must be a table, got " .. type(compat._installed))
end)

-- ─── Summary ───
io.write(string.format("\n=== Results: %d passed, %d failed ===\n", passed, failed))
if #errors > 0 then
  io.write("\nFailures:\n")
  for _, e in ipairs(errors) do
    io.write("  " .. e.name .. ": " .. tostring(e.err) .. "\n")
  end
end
io.write("\n")

if failed > 0 then
  os.exit(1)
end
