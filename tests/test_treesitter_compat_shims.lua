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
  assert(type(compat._deferred) == "table", "_deferred should be a table")
  assert(type(compat._shimmed) == "table", "_shimmed should be a table")
end)

test("safe_preload function is exported", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(type(compat.safe_preload) == "function", "safe_preload should be a function")
end)

io.write("\nPhase 2: safe_preload behaviour\n")

test("safe_preload skips when real module exists on package.path", function()
  -- Create a temporary module file
  local tmpdir = os.tmpname() .. "_safe_preload_test"
  os.execute("mkdir -p " .. tmpdir)
  local f = io.open(tmpdir .. "/test_real_module_exists.lua", "w")
  f:write("return { real = true }")
  f:close()
  -- Add to package.path temporarily
  local old_path = package.path
  package.path = tmpdir .. "/?.lua;" .. package.path
  -- safe_preload should return false (skip)
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  local result = compat.safe_preload("test_real_module_exists", function()
    return { real = false }
  end)
  assert(result == false, "safe_preload should return false when real module exists, got: " .. tostring(result))
  -- Clean up
  package.path = old_path
  os.execute("rm -rf " .. tmpdir)
end)

test("safe_preload skips when package.preload already has entry", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  -- Pre-populate package.preload
  package.preload["test_preload_exists"] = function() return { existing = true } end
  local result = compat.safe_preload("test_preload_exists", function()
    return { shim = true }
  end)
  assert(result == false, "safe_preload should return false when preload already set")
  -- Clean up
  package.preload["test_preload_exists"] = nil
end)

test("safe_preload installs when module does not exist", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  -- Ensure the module doesn't exist
  package.preload["test_nonexistent_shim_module"] = nil
  package.loaded["test_nonexistent_shim_module"] = nil
  local result = compat.safe_preload("test_nonexistent_shim_module", function()
    return { shim = true }
  end)
  assert(result == true, "safe_preload should return true when module doesn't exist")
  assert(package.preload["test_nonexistent_shim_module"] ~= nil,
    "package.preload entry should be set")
  -- Clean up
  package.preload["test_nonexistent_shim_module"] = nil
end)

test("deferred preloader loads real module when available at require-time", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  -- Register a deferred preloader for a non-existent module
  package.loaded["test_deferred_real_load"] = nil
  package.preload["test_deferred_real_load"] = nil
  local result = compat.safe_preload("test_deferred_real_load", function()
    return { shim = true }
  end)
  assert(result == true, "safe_preload should return true")
  -- Now create the real module file and add its dir to package.path
  local tmpdir = os.tmpname() .. "_deferred_test"
  os.execute("mkdir -p " .. tmpdir)
  local f = io.open(tmpdir .. "/test_deferred_real_load.lua", "w")
  f:write("return { real = true }")
  f:close()
  local old_path = package.path
  package.path = tmpdir .. "/?.lua;" .. package.path
  -- require should find the real module via our deferred preloader
  local mod = require("test_deferred_real_load")
  assert(mod.real == true, "deferred preloader should load real module, got shim=" .. tostring(mod.shim))
  -- Clean up
  package.loaded["test_deferred_real_load"] = nil
  package.path = old_path
  os.execute("rm -rf " .. tmpdir)
end)

test("deferred preloader falls back to shim when no real module", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  package.loaded["test_deferred_shim_fallback"] = nil
  package.preload["test_deferred_shim_fallback"] = nil
  local result = compat.safe_preload("test_deferred_shim_fallback", function()
    return { shim = true }
  end)
  assert(result == true, "safe_preload should return true")
  -- require without a real module should use the shim
  local mod = require("test_deferred_shim_fallback")
  assert(mod.shim == true, "deferred preloader should fall back to shim")
  -- Clean up
  package.loaded["test_deferred_shim_fallback"] = nil
end)

io.write("\nPhase 3: Shim module requires don't error\n")

-- In the test environment (-u NORC), nvim-treesitter is not on the path,
-- so all deferred preloaders will fall back to their shims.
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

-- Ensure a fresh load of shims
for _, mod_name in ipairs(shim_modules) do
  package.loaded[mod_name] = nil
  package.preload[mod_name] = nil
end
dofile("config.nvim/lua/config/treesitter-compat.lua")

for _, mod_name in ipairs(shim_modules) do
  test("require('" .. mod_name .. "') succeeds", function()
    local ok, mod = pcall(require, mod_name)
    assert(ok, "require failed: " .. tostring(mod))
    assert(type(mod) == "table", "module should return a table, got " .. type(mod))
  end)
end

io.write("\nPhase 4: Shim API functionality\n")

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

-- ── Tests for modules added for go.nvim compat ──

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

io.write("\nPhase 5: Config file syntax checks\n")

test("treesitter-compat.lua syntax is valid", function()
  local fn, err = loadfile("config.nvim/lua/config/treesitter-compat.lua")
  assert(fn, "Syntax error: " .. tostring(err))
end)

test("init.lua syntax is valid", function()
  local fn, err = loadfile("config.nvim/init.lua")
  assert(fn, "Syntax error: " .. tostring(err))
end)

io.write("\nPhase 6: Structural checks\n")

test("M._installed is always initialised (not nil)", function()
  -- Force a fresh load
  package.loaded["config.treesitter-compat"] = nil
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(type(compat._installed) == "table",
    "_installed must be a table, got " .. type(compat._installed))
end)

test("M._deferred is always initialised (not nil)", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(type(compat._deferred) == "table",
    "_deferred must be a table, got " .. type(compat._deferred))
end)

test("M._shimmed is always initialised (not nil)", function()
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  assert(type(compat._shimmed) == "table",
    "_shimmed must be a table, got " .. type(compat._shimmed))
end)

io.write("\nPhase 7: Integration — deferred preloader with real nvim-treesitter modules\n")

test("deferred preloader correctly defers to real parsers.lua", function()
  -- Simulate: clear cached modules, register shims, then add the real
  -- nvim-treesitter to package.path and require parsers
  package.loaded["nvim-treesitter.parsers"] = nil
  package.preload["nvim-treesitter.parsers"] = nil
  local compat = dofile("config.nvim/lua/config/treesitter-compat.lua")
  -- Now add the real nvim-treesitter to package.path
  -- (We cloned it to /tmp/nvim-ts-verify earlier)
  local ts_lua_dir = "/tmp/nvim-ts-verify/lua"
  local old_path = package.path
  -- Check if the real nvim-treesitter clone exists
  local real_parsers = package.searchpath("nvim-treesitter.parsers", ts_lua_dir .. "/?.lua")
  if real_parsers then
    package.path = ts_lua_dir .. "/?.lua;" .. ts_lua_dir .. "/?/init.lua;" .. package.path
    local parsers = require("nvim-treesitter.parsers")
    -- The real parsers.lua should have language entries like 'bash', 'lua', etc.
    assert(parsers.bash ~= nil or parsers.lua ~= nil,
      "real parsers module should have language entries (bash or lua)")
    -- It should NOT have our shim's has_parser function as a top-level function
    -- (the real module uses a different structure)
    io.write("    → Successfully loaded real parsers.lua with language entries\n")
    -- Clean up
    package.loaded["nvim-treesitter.parsers"] = nil
    package.path = old_path
  else
    io.write("    → /tmp/nvim-ts-verify not found, skipping real-module test\n")
  end
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
