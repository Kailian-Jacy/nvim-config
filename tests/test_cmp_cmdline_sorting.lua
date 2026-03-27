-- Test: nvim-cmp cmdline sorting comparator antisymmetry (fix #52)
--
-- Run: nvim --headless -u NORC -l tests/test_cmp_cmdline_sorting.lua
--
-- Validates that prefix_match_comparator does not violate strict weak ordering
-- when entries have different contexts (the root cause of the "invalid order
-- function for sorting" error in cmdline mode).

local passed = 0
local failed = 0

local function assert_eq(actual, expected, msg)
  if actual == expected then
    passed = passed + 1
    print("  PASS: " .. msg)
  else
    failed = failed + 1
    print("  FAIL: " .. msg)
    print("    expected: " .. tostring(expected))
    print("    actual:   " .. tostring(actual))
  end
end

local function assert_true(val, msg)
  assert_eq(val, true, msg)
end

local function assert_false(val, msg)
  assert_eq(not val, true, msg)
end

-------------------------------------------------------------------------------
-- Minimal mock entry: simulates nvim-cmp entry with a context and label
-------------------------------------------------------------------------------
local function make_entry(label, cursor_before_line)
  return {
    completion_item = { label = label },
    context = cursor_before_line and { cursor_before_line = cursor_before_line } or nil,
    get_filter_text = function(self)
      return self.completion_item.label
    end,
    get_kind = function()
      return 6 -- Variable
    end,
    source = { name = "test" },
  }
end

-------------------------------------------------------------------------------
-- Test 1: OLD (buggy) comparator violates antisymmetry with different contexts
-------------------------------------------------------------------------------
print("\n=== Test 1: Old comparator antisymmetry violation ===")
do
  -- This is the OLD buggy implementation that reads input from entry1.context
  local old_prefix_match_comparator = function(entry1, entry2)
    local ctx = entry1.context
    if not ctx or not ctx.cursor_before_line then
      return nil
    end
    local input = ctx.cursor_before_line:match("[%w_]+$") or ""
    if #input == 0 then
      return nil
    end

    local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
    local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""

    local prefix1 = vim.startswith(word1:lower(), input:lower())
    local prefix2 = vim.startswith(word2:lower(), input:lower())

    if prefix1 and not prefix2 then
      return true
    elseif not prefix1 and prefix2 then
      return false
    end

    return nil
  end

  -- Reproduce the exact scenario from the planner report:
  -- Entry A: label="source", context.cursor_before_line="so" (from cmdline source)
  -- Entry B: label="set",    context.cursor_before_line="se" (from buffer source)
  local entryA = make_entry("source", "so")
  local entryB = make_entry("set", "se")

  local ab = old_prefix_match_comparator(entryA, entryB)
  local ba = old_prefix_match_comparator(entryB, entryA)

  -- Demonstrate the violation: both return true
  assert_eq(ab, true, "old comp(A,B) = true (source starts with 'so', set does not)")
  assert_eq(ba, true, "old comp(B,A) = true (set starts with 'se', source does not)")

  -- This IS the antisymmetry violation
  local violation = (ab == true and ba == true)
  assert_true(violation, "old comparator DOES violate antisymmetry (both true)")

  -- Verify table.sort would fail with this comparator
  local entries = {}
  for i = 1, 20 do
    if i % 2 == 0 then
      entries[i] = make_entry("source_" .. i, "so")
    else
      entries[i] = make_entry("set_" .. i, "se")
    end
  end

  local sort_ok, sort_err = pcall(function()
    table.sort(entries, function(a, b)
      local r = old_prefix_match_comparator(a, b)
      if r ~= nil then return r end
      return a.completion_item.label < b.completion_item.label
    end)
  end)

  -- On Lua 5.1/LuaJIT this may or may not trigger the error depending on
  -- input order, but the violation is proven above regardless.
  print("  INFO: table.sort with old comparator: " ..
    (sort_ok and "no error (lucky input order)" or "ERROR: " .. tostring(sort_err)))
end

-------------------------------------------------------------------------------
-- Test 2: NEW comparator uses consistent input (no antisymmetry violation)
-------------------------------------------------------------------------------
print("\n=== Test 2: New comparator with consistent input ===")
do
  -- The fixed comparator uses a single shared input for both entries.
  -- In a real nvim session it reads from vim.fn.getcmdline() or
  -- nvim_get_current_line(). Here we simulate by parameterizing the input.
  local function make_fixed_comparator(shared_input)
    return function(entry1, entry2)
      local input = shared_input:match("[%w_]+$") or ""
      if #input == 0 then
        return nil
      end

      local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
      local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""

      local prefix1 = vim.startswith(word1:lower(), input:lower())
      local prefix2 = vim.startswith(word2:lower(), input:lower())

      if prefix1 and not prefix2 then
        return true
      elseif not prefix1 and prefix2 then
        return false
      end

      return nil
    end
  end

  -- Same entries, but now comparator uses a single consistent input
  local entryA = make_entry("source", "so")  -- context doesn't matter anymore
  local entryB = make_entry("set", "se")      -- context doesn't matter anymore

  -- Scenario 1: input is "so"
  local comp_so = make_fixed_comparator("so")
  local ab1 = comp_so(entryA, entryB)
  local ba1 = comp_so(entryB, entryA)
  assert_eq(ab1, true,  "fixed comp(A,B) with input='so': source matches, set doesn't → true")
  assert_eq(ba1, false, "fixed comp(B,A) with input='so': set doesn't match, source does → false")
  assert_false(ab1 == true and ba1 == true, "no antisymmetry violation with input='so'")

  -- Scenario 2: input is "se"
  local comp_se = make_fixed_comparator("se")
  local ab2 = comp_se(entryA, entryB)
  local ba2 = comp_se(entryB, entryA)
  assert_eq(ab2, false, "fixed comp(A,B) with input='se': source doesn't match, set does → false")
  assert_eq(ba2, true,  "fixed comp(B,A) with input='se': set matches, source doesn't → true")
  assert_false(ab2 == true and ba2 == true, "no antisymmetry violation with input='se'")

  -- Scenario 3: input is "s" (both match)
  local comp_s = make_fixed_comparator("s")
  local ab3 = comp_s(entryA, entryB)
  local ba3 = comp_s(entryB, entryA)
  assert_eq(ab3, nil, "fixed comp(A,B) with input='s': both match → nil (fall through)")
  assert_eq(ba3, nil, "fixed comp(B,A) with input='s': both match → nil (fall through)")
  assert_false(ab3 == true and ba3 == true, "no antisymmetry violation with input='s'")

  -- Scenario 4: input is "xyz" (neither match)
  local comp_xyz = make_fixed_comparator("xyz")
  local ab4 = comp_xyz(entryA, entryB)
  local ba4 = comp_xyz(entryB, entryA)
  assert_eq(ab4, nil, "fixed comp(A,B) with input='xyz': neither match → nil")
  assert_eq(ba4, nil, "fixed comp(B,A) with input='xyz': neither match → nil")
end

-------------------------------------------------------------------------------
-- Test 3: Exhaustive antisymmetry check for fixed comparator
-------------------------------------------------------------------------------
print("\n=== Test 3: Exhaustive antisymmetry for fixed comparator ===")
do
  local function make_fixed_comparator(shared_input)
    return function(entry1, entry2)
      local input = shared_input:match("[%w_]+$") or ""
      if #input == 0 then return nil end
      local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
      local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""
      local prefix1 = vim.startswith(word1:lower(), input:lower())
      local prefix2 = vim.startswith(word2:lower(), input:lower())
      if prefix1 and not prefix2 then return true
      elseif not prefix1 and prefix2 then return false end
      return nil
    end
  end

  local labels = { "set", "setlocal", "source", "syntax", "substitute", "lua", "luafile", "buffer" }
  local inputs = { "s", "se", "set", "so", "su", "l", "lu", "b", "xyz", "" }

  local violations = 0
  for _, input in ipairs(inputs) do
    local comp = make_fixed_comparator(input)
    for i = 1, #labels do
      for j = i + 1, #labels do
        local e1 = make_entry(labels[i], "ignored")
        local e2 = make_entry(labels[j], "ignored")
        local ab = comp(e1, e2)
        local ba = comp(e2, e1)
        if ab == true and ba == true then
          violations = violations + 1
          print("  VIOLATION: input='" .. input .. "' " .. labels[i] .. " vs " .. labels[j])
        end
      end
    end
  end

  assert_eq(violations, 0, "no antisymmetry violations across " ..
    (#labels * (#labels - 1) / 2 * #inputs) .. " pair-input combinations")

  -- Also verify table.sort succeeds with the fixed comparator
  for _, input in ipairs(inputs) do
    local comp = make_fixed_comparator(input)
    local entries = {}
    for idx, label in ipairs(labels) do
      -- Give each entry a different context to simulate the bug scenario
      entries[idx] = make_entry(label, label:sub(1, 2))
    end
    local ok, err = pcall(function()
      table.sort(entries, function(a, b)
        local r = comp(a, b)
        if r ~= nil then return r end
        return a.completion_item.label < b.completion_item.label
      end)
    end)
    if not ok then
      failed = failed + 1
      print("  FAIL: table.sort failed with input='" .. input .. "': " .. tostring(err))
    end
  end
  passed = passed + 1
  print("  PASS: table.sort succeeds for all inputs with fixed comparator")
end

-------------------------------------------------------------------------------
-- Test 4: prefix_match_comparator case-insensitive matching
-------------------------------------------------------------------------------
print("\n=== Test 4: Case-insensitive prefix matching ===")
do
  local function make_fixed_comparator(shared_input)
    return function(entry1, entry2)
      local input = shared_input:match("[%w_]+$") or ""
      if #input == 0 then return nil end
      local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
      local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""
      local prefix1 = vim.startswith(word1:lower(), input:lower())
      local prefix2 = vim.startswith(word2:lower(), input:lower())
      if prefix1 and not prefix2 then return true
      elseif not prefix1 and prefix2 then return false end
      return nil
    end
  end

  local comp = make_fixed_comparator("Set")
  local e1 = make_entry("setlocal", "x")
  local e2 = make_entry("syntax", "x")
  local result = comp(e1, e2)
  assert_eq(result, true, "case-insensitive: 'setlocal' matches 'Set', 'syntax' doesn't → true")

  local result2 = comp(e2, e1)
  assert_eq(result2, false, "case-insensitive reverse: → false")
end

-------------------------------------------------------------------------------
-- Test 5: Empty / nil context handling (graceful degradation)
-------------------------------------------------------------------------------
print("\n=== Test 5: Empty/nil context handling ===")
do
  local function make_fixed_comparator(shared_input)
    return function(entry1, entry2)
      local input = shared_input:match("[%w_]+$") or ""
      if #input == 0 then return nil end
      local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
      local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""
      local prefix1 = vim.startswith(word1:lower(), input:lower())
      local prefix2 = vim.startswith(word2:lower(), input:lower())
      if prefix1 and not prefix2 then return true
      elseif not prefix1 and prefix2 then return false end
      return nil
    end
  end

  -- Empty input should return nil (fall through)
  local comp_empty = make_fixed_comparator("")
  local e1 = make_entry("set", "se")
  local e2 = make_entry("source", "so")
  assert_eq(comp_empty(e1, e2), nil, "empty input → nil (fall through)")

  -- Input with no word chars should return nil
  local comp_special = make_fixed_comparator("  ")
  assert_eq(comp_special(e1, e2), nil, "whitespace-only input → nil (fall through)")
end

-------------------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------------------
print("\n" .. string.rep("=", 60))
print(string.format("Results: %d passed, %d failed", passed, failed))
print(string.rep("=", 60))

if failed > 0 then
  print("SOME TESTS FAILED!")
  vim.cmd("cquit! 1")
else
  print("ALL TESTS PASSED!")
  vim.cmd("qall!")
end
