-- Test for Issue #54: <C-G> Shows "N.A." Instead of Breadcrumb Context
--
-- Verifies that the documentSymbol request params are correctly formatted
-- and that the symbol tree walk logic produces correct breadcrumb paths.
--
-- Run: nvim --headless -u NORC -l tests/test_cg_breadcrumb.lua
--
-- What this tests:
--   1. make_text_document_params() returns a table with a `uri` field
--   2. DocumentSymbolParams wraps it as { textDocument = { uri = ... } }
--   3. Symbol tree walk logic produces correct breadcrumb paths
--   4. Edge cases: cursor outside symbols, nested symbols, empty result

local passed = 0
local failed = 0

local function log(msg)
  print(msg)
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

--- Replicate the walk logic from keymaps.lua for unit testing
local function walk_symbols(symbols, row)
  local path = {}
  local function walk(syms)
    for _, sym in ipairs(syms) do
      local range = sym.range or sym.location and sym.location.range
      if range and range.start.line <= row and range["end"].line >= row then
        table.insert(path, sym.name)
        if sym.children then walk(sym.children) end
        return
      end
    end
  end
  walk(symbols)
  return path
end

log("=== Issue #54: C-g Breadcrumb DocumentSymbol Params Tests ===")
log("")

-- Locate source files relative to this test
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local repo_root = test_dir:gsub("tests/$", "")
local keymaps_lua = repo_root .. "config.nvim/lua/config/keymaps.lua"

-- ============================================================
-- Test 1: make_text_document_params() returns { uri = ... }
-- ============================================================
log("[Test 1] make_text_document_params() return format")

local tdp = vim.lsp.util.make_text_document_params()
assert_test(
  "make_text_document_params() returns a table",
  type(tdp) == "table",
  "Expected table, got " .. type(tdp)
)
assert_test(
  "make_text_document_params() has 'uri' field",
  tdp.uri ~= nil,
  "Missing 'uri' field"
)
assert_test(
  "make_text_document_params() uri is a string",
  type(tdp.uri) == "string",
  "Expected uri to be string, got " .. type(tdp.uri)
)
-- It should NOT have a textDocument wrapper — that's what we need to add
assert_test(
  "make_text_document_params() does NOT have 'textDocument' field (raw)",
  tdp.textDocument == nil,
  "Unexpected 'textDocument' field — this function returns a bare TextDocumentIdentifier"
)

-- ============================================================
-- Test 2: Correct DocumentSymbolParams format
-- ============================================================
log("")
log("[Test 2] DocumentSymbolParams construction")

local params = { textDocument = vim.lsp.util.make_text_document_params() }
assert_test(
  "params has 'textDocument' field",
  params.textDocument ~= nil,
  "Missing 'textDocument' wrapper"
)
assert_test(
  "params.textDocument has 'uri' field",
  params.textDocument.uri ~= nil,
  "Missing 'textDocument.uri'"
)
assert_test(
  "params.textDocument.uri is a string",
  type(params.textDocument.uri) == "string",
  "Expected string, got " .. type(params.textDocument.uri)
)

-- ============================================================
-- Test 3: keymaps.lua source code uses correct wrapping
-- ============================================================
log("")
log("[Test 3] keymaps.lua source has correct params wrapping")

local keymaps_content = read_file(keymaps_lua)
assert_test(
  "keymaps.lua is readable",
  keymaps_content ~= nil,
  "Could not read " .. keymaps_lua
)

if keymaps_content then
  -- Find the C-G mapping section
  local cg_section = keymaps_content:match('<C%-G>.-end%)')
  assert_test(
    "C-G keymap section found",
    cg_section ~= nil,
    "Could not locate the <C-G> keymap in keymaps.lua"
  )

  if cg_section then
    -- Must have { textDocument = ... make_text_document_params() }
    local has_wrapper = cg_section:find('{%s*textDocument%s*=%s*vim%.lsp%.util%.make_text_document_params%(%)%s*}') ~= nil
    assert_test(
      "params wrapped in { textDocument = ... }",
      has_wrapper,
      "make_text_document_params() must be wrapped: { textDocument = make_text_document_params() }"
    )

    -- Must NOT have bare make_text_document_params() as params (the old bug)
    -- i.e., "local params = vim.lsp.util.make_text_document_params()" without textDocument
    local has_bare = cg_section:find('local params = vim%.lsp%.util%.make_text_document_params%(%)%s*\n') ~= nil
    assert_test(
      "No bare make_text_document_params() as params (old bug)",
      not has_bare,
      "Found unwrapped make_text_document_params() — this is the bug from issue #54"
    )
  end
end

-- ============================================================
-- Test 4: Symbol tree walk logic — basic case
-- ============================================================
log("")
log("[Test 4] Symbol tree walk — basic cases")

-- Mock symbol tree: a module containing a function
local mock_symbols = {
  {
    name = "MyModule",
    kind = 2, -- Module
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = 50, character = 0 },
    },
    children = {
      {
        name = "my_function",
        kind = 12, -- Function
        range = {
          start = { line = 10, character = 2 },
          ["end"] = { line = 20, character = 2 },
        },
        children = {},
      },
      {
        name = "other_function",
        kind = 12,
        range = {
          start = { line = 25, character = 2 },
          ["end"] = { line = 35, character = 2 },
        },
      },
    },
  },
}

-- Cursor on line 15 (inside MyModule > my_function)
local path = walk_symbols(mock_symbols, 15)
assert_test(
  "Cursor inside nested symbol returns correct path",
  #path == 2 and path[1] == "MyModule" and path[2] == "my_function",
  "Expected {'MyModule', 'my_function'}, got {" .. table.concat(path, ", ") .. "}"
)

-- Cursor on line 30 (inside MyModule > other_function)
path = walk_symbols(mock_symbols, 30)
assert_test(
  "Cursor in sibling function returns correct path",
  #path == 2 and path[1] == "MyModule" and path[2] == "other_function",
  "Expected {'MyModule', 'other_function'}, got {" .. table.concat(path, ", ") .. "}"
)

-- Cursor on line 5 (inside MyModule but outside any function)
path = walk_symbols(mock_symbols, 5)
assert_test(
  "Cursor in parent but outside children returns parent only",
  #path == 1 and path[1] == "MyModule",
  "Expected {'MyModule'}, got {" .. table.concat(path, ", ") .. "}"
)

-- ============================================================
-- Test 5: Symbol tree walk — edge cases
-- ============================================================
log("")
log("[Test 5] Symbol tree walk — edge cases")

-- Empty result
path = walk_symbols({}, 10)
assert_test(
  "Empty symbol list returns empty path",
  #path == 0,
  "Expected empty path, got " .. #path .. " elements"
)

-- Cursor outside all symbols
path = walk_symbols(mock_symbols, 100)
assert_test(
  "Cursor outside all symbols returns empty path",
  #path == 0,
  "Expected empty path for cursor at line 100"
)

-- Deeply nested symbols (3 levels)
local deep_symbols = {
  {
    name = "Class",
    kind = 5,
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 100, character = 0 } },
    children = {
      {
        name = "method",
        kind = 6,
        range = { start = { line = 10, character = 0 }, ["end"] = { line = 50, character = 0 } },
        children = {
          {
            name = "inner_closure",
            kind = 12,
            range = { start = { line = 20, character = 0 }, ["end"] = { line = 30, character = 0 } },
            children = {},
          },
        },
      },
    },
  },
}

path = walk_symbols(deep_symbols, 25)
assert_test(
  "Deeply nested (3 levels) returns full path",
  #path == 3 and path[1] == "Class" and path[2] == "method" and path[3] == "inner_closure",
  "Expected {'Class', 'method', 'inner_closure'}, got {" .. table.concat(path, ", ") .. "}"
)

-- Cursor at exact boundary (start line of symbol)
path = walk_symbols(mock_symbols, 10)
assert_test(
  "Cursor at symbol start line is included",
  #path == 2 and path[2] == "my_function",
  "Expected cursor at start line to be inside symbol"
)

-- Cursor at exact boundary (end line of symbol)
path = walk_symbols(mock_symbols, 20)
assert_test(
  "Cursor at symbol end line is included",
  #path == 2 and path[2] == "my_function",
  "Expected cursor at end line to be inside symbol"
)

-- Symbols using location.range instead of range (DocumentSymbol vs SymbolInformation)
local location_symbols = {
  {
    name = "func_with_location",
    kind = 12,
    location = {
      uri = "file:///test.lua",
      range = {
        start = { line = 5, character = 0 },
        ["end"] = { line = 15, character = 0 },
      },
    },
  },
}

path = walk_symbols(location_symbols, 10)
assert_test(
  "Symbols with location.range (SymbolInformation format) work",
  #path == 1 and path[1] == "func_with_location",
  "Expected {'func_with_location'}, got {" .. table.concat(path, ", ") .. "}"
)

-- ============================================================
-- Summary
-- ============================================================
log("")
log(string.format("=== Results: %d passed, %d failed ===", passed, failed))

if failed > 0 then
  vim.cmd("cq!")  -- exit with error code
else
  vim.cmd("qa!")
end
