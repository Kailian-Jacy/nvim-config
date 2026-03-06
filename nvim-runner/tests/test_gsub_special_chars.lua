-- nvim-runner/tests/test_gsub_special_chars.lua
-- Comprehensive tests for string.gsub % special character issues
-- and the safe_replace functions.
--
-- Run: cd nvim-runner && nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_gsub_special_chars.lua"

local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

-- Test framework
local results = {}
local pass_count = 0
local fail_count = 0

local function record(status, name, detail)
  if status == "PASS" then
    pass_count = pass_count + 1
  elseif status == "FAIL" then
    fail_count = fail_count + 1
  end
  local msg = string.format("[%s] %s", status, name)
  if detail then
    msg = msg .. " -- " .. detail
  end
  table.insert(results, msg)
  io.write(msg .. "\n")
  io.flush()
end

local function assert_eq(got, expected, test_name, detail)
  if got == expected then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, string.format("expected=%q, got=%q", tostring(expected), tostring(got)))
    return false
  end
end

local function assert_true(val, test_name, detail)
  if val then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, detail or "expected truthy value")
    return false
  end
end

io.write("\n========================================\n")
io.write("  gsub special chars test suite\n")
io.write("========================================\n\n")

local runner = require("nvim-runner.runner")
local safe_replace = runner._safe_replace
local safe_replace_all = runner._safe_replace_all

-- ============================================
-- 1. Demonstrate the original gsub bug
-- ============================================
io.write("--- Demonstrating original gsub bug ---\n")

do
  -- gsub's replacement string treats % as special
  -- %d in replacement is interpreted as capture reference #d
  local template = "echo -e | ${runner} <<EOF\n${text}\nEOF"

  -- Python code with % formatting
  local python_code = 'print("%d" % 42)'

  -- Using string.gsub for ${text} replacement:
  -- The replacement string contains %d which gsub interprets as capture group 1
  local crashed = false
  local gsub_result = nil
  local ok, err = pcall(function()
    local t = string.gsub(template, "${runner}", "python3")
    gsub_result = string.gsub(t, "${text}", python_code)
  end)

  if not ok then
    crashed = true
    record("PASS", "gsub-bug-demo: gsub crashes with %d in replacement", tostring(err))
  else
    -- It might not crash but produce wrong output
    local expected = 'echo -e | python3 <<EOF\nprint("%d" % 42)\nEOF'
    if gsub_result ~= expected then
      record("PASS", "gsub-bug-demo: gsub produces wrong output with %d in replacement",
        string.format("got=%q", gsub_result))
    else
      record("FAIL", "gsub-bug-demo: expected gsub to misbehave but it worked correctly")
    end
  end
end

do
  -- %s in replacement
  local ok, result = pcall(function()
    return string.gsub("${text}", "${text}", 'format("%s" % "hello")')
  end)
  if not ok then
    record("PASS", "gsub-bug-demo: gsub crashes with %s in replacement", tostring(result))
  else
    local expected = 'format("%s" % "hello")'
    if result ~= expected then
      record("PASS", "gsub-bug-demo: gsub corrupts %s in replacement",
        string.format("got=%q", result))
    else
      record("FAIL", "gsub-bug-demo: expected gsub to misbehave with %s")
    end
  end
end

-- ============================================
-- 2. safe_replace basic functionality
-- ============================================
io.write("\n--- safe_replace basic tests ---\n")

do
  assert_eq(
    safe_replace("hello ${text} world", "${text}", "foo"),
    "hello foo world",
    "safe_replace: basic replacement"
  )

  assert_eq(
    safe_replace("no match here", "${text}", "foo"),
    "no match here",
    "safe_replace: no match returns original"
  )

  assert_eq(
    safe_replace("${text}${text}", "${text}", "foo"),
    "foo${text}",
    "safe_replace: only replaces first occurrence"
  )

  assert_eq(
    safe_replace("", "${text}", "foo"),
    "",
    "safe_replace: empty string"
  )

  assert_eq(
    safe_replace("${text}", "${text}", ""),
    "",
    "safe_replace: replace with empty string"
  )
end

-- ============================================
-- 3. safe_replace_all basic functionality
-- ============================================
io.write("\n--- safe_replace_all basic tests ---\n")

do
  assert_eq(
    safe_replace_all("hello ${text} world ${text} end", "${text}", "foo"),
    "hello foo world foo end",
    "safe_replace_all: replaces all occurrences"
  )

  assert_eq(
    safe_replace_all("no match", "${text}", "foo"),
    "no match",
    "safe_replace_all: no match returns original"
  )

  assert_eq(
    safe_replace_all("${text}${text}${text}", "${text}", "x"),
    "xxx",
    "safe_replace_all: adjacent occurrences"
  )

  assert_eq(
    safe_replace_all("", "${text}", "foo"),
    "",
    "safe_replace_all: empty string"
  )

  assert_eq(
    safe_replace_all("aaa", "", "foo"),
    "aaa",
    "safe_replace_all: empty target returns original"
  )
end

-- ============================================
-- 4. Python % format strings
-- ============================================
io.write("\n--- Python % format strings ---\n")

do
  local template = "echo -e | ${runner} <<EOF\n${text}\nEOF"

  -- %d format
  local code_d = 'print("%d" % 42)'
  local result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_d)
  assert_eq(result, 'echo -e | python3 <<EOF\nprint("%d" % 42)\nEOF',
    "python-%d: safe_replace handles %d in code")

  -- %s format
  local code_s = 'print("%s" % "hello")'
  result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_s)
  assert_eq(result, 'echo -e | python3 <<EOF\nprint("%s" % "hello")\nEOF',
    "python-%s: safe_replace handles %s in code")

  -- %f format
  local code_f = 'print("%.2f" % 3.14)'
  result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_f)
  assert_eq(result, 'echo -e | python3 <<EOF\nprint("%.2f" % 3.14)\nEOF',
    "python-%f: safe_replace handles %.2f in code")

  -- %% literal percent
  local code_pct = 'print("100%%")'
  result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_pct)
  assert_eq(result, 'echo -e | python3 <<EOF\nprint("100%%")\nEOF',
    "python-%%: safe_replace handles %% in code")

  -- Multiple % in one line
  local code_multi = 'print("name: %s, age: %d, score: %.1f" % ("Alice", 30, 95.5))'
  result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_multi)
  assert_eq(result,
    'echo -e | python3 <<EOF\nprint("name: %s, age: %d, score: %.1f" % ("Alice", 30, 95.5))\nEOF',
    "python-multi-%: safe_replace handles multiple % formats")

  -- %r, %x, %o, %e
  local code_other = 'x = "%r %x %o %e" % (obj, 255, 8, 1.5)'
  result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_other)
  assert_eq(result,
    'echo -e | python3 <<EOF\nx = "%r %x %o %e" % (obj, 255, 8, 1.5)\nEOF',
    "python-%r%x%o%e: safe_replace handles exotic % formats")
end

-- ============================================
-- 5. Shell % characters
-- ============================================
io.write("\n--- Shell % characters ---\n")

do
  local template = "${text}"

  -- Shell with printf %d
  local code = 'printf "%d\\n" 42'
  local result = safe_replace_all(template, "${text}", code)
  assert_eq(result, code, "shell-%d: printf %d preserved")

  -- Shell with %% in date format
  local code2 = 'date +"%Y-%%m-%%d"'
  result = safe_replace_all(template, "${text}", code2)
  assert_eq(result, code2, "shell-%%: date %% preserved")

  -- Shell with awk and %
  local code3 = [[awk '{printf "%s: %.2f%%\n", $1, $2}']]
  result = safe_replace_all(template, "${text}", code3)
  assert_eq(result, code3, "shell-awk-%: awk with % preserved")
end

-- ============================================
-- 6. Lua % pattern characters
-- ============================================
io.write("\n--- Lua % pattern characters ---\n")

do
  local template = "${text}"

  -- Lua pattern with %d, %s, %a, %w etc.
  local code = 'local m = str:match("%d+%.%d+")'
  local result = safe_replace_all(template, "${text}", code)
  assert_eq(result, code, "lua-%d-pattern: Lua pattern match preserved")

  -- Lua gsub with capture references
  local code2 = 'local r = s:gsub("(%w+)", "%1_suffix")'
  result = safe_replace_all(template, "${text}", code2)
  assert_eq(result, code2, "lua-gsub-capture: capture reference %1 preserved")

  -- Lua with %% literal
  local code3 = 'print(string.format("%.1f%%", 99.9))'
  result = safe_replace_all(template, "${text}", code3)
  assert_eq(result, code3, "lua-%%: format %% preserved")
end

-- ============================================
-- 7. ${runner} and ${text} appearing in code content
-- ============================================
io.write("\n--- Placeholder strings in code content ---\n")

do
  local template = "echo -e | ${runner} <<EOF\n${text}\nEOF"

  -- Code that literally contains "${runner}"
  local code_with_runner = 'echo "the ${runner} variable"'
  local result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", code_with_runner)
  -- Since we replace ${runner} first, ${runner} in the template is replaced with python3.
  -- Then ${text} is replaced. The ${runner} inside the code content should NOT be touched
  -- because it was already in the replacement string (not in the template).
  assert_eq(result,
    'echo -e | python3 <<EOF\necho "the ${runner} variable"\nEOF',
    "placeholder-in-code: ${runner} in code content preserved after replacement order")

  -- Code that literally contains "${text}"
  local code_with_text = 'echo "show ${text} here"'
  result = safe_replace_all(template, "${runner}", "bash")
  result = safe_replace_all(result, "${text}", code_with_text)
  -- After replacing ${text}, the ${text} inside the code should be in the output
  -- But wait: safe_replace_all replaces ALL ${text} including the one just inserted!
  -- This is actually a known limitation. Let's document the actual behavior.
  -- With safe_replace (first occurrence only), the template's ${text} gets replaced,
  -- but the ${text} inside the code becomes part of the result and won't be re-scanned.
  -- Actually safe_replace_all scans the original string, not the result. Let me verify...

  -- Actually safe_replace_all finds all occurrences in the source string before any replacement.
  -- But we're calling it on a string that may already have ${text} from a previous replacement.
  -- The template has exactly one ${text}, so after replacing it, the result contains
  -- the code_with_text which has ${text} but that's in the RESULT, not in the source at scan time.
  -- Wait no - safe_replace_all uses pos tracking, scanning left to right. After the first ${text}
  -- is replaced with code_with_text (which contains ${text}), the pos moves past j+1.
  -- The inserted text is NOT re-scanned because we skip ahead. Let me verify...

  -- Actually, in safe_replace_all, after replacing at position i..j, pos = j+1,
  -- where j is the end of the ORIGINAL match. The replacement is appended to result
  -- but the scan continues from pos = j+1 in the ORIGINAL string. So the replacement
  -- content is never re-scanned. This is correct!

  assert_eq(result,
    'echo -e | bash <<EOF\necho "show ${text} here"\nEOF',
    "placeholder-in-code: ${text} in code content preserved (not re-scanned)")
end

do
  -- Edge case: code contains both ${runner} and ${text}
  local template = "${runner} -c '${text}'"
  local code = 'echo "${runner} says ${text}"'
  local result = safe_replace_all(template, "${runner}", "bash")
  result = safe_replace_all(result, "${text}", code)
  assert_eq(result,
    'bash -c \'echo "${runner} says ${text}"\'',
    "placeholder-both: both placeholders in code preserved correctly")
end

-- ============================================
-- 8. Edge cases: empty and weird inputs
-- ============================================
io.write("\n--- Edge cases ---\n")

do
  -- Replacement that is just %
  assert_eq(
    safe_replace_all("a ${text} b", "${text}", "%"),
    "a % b",
    "edge: single % as replacement"
  )

  -- Replacement that is just %%
  assert_eq(
    safe_replace_all("a ${text} b", "${text}", "%%"),
    "a %% b",
    "edge: %% as replacement"
  )

  -- Replacement with %0 (gsub would treat as full match)
  assert_eq(
    safe_replace_all("a ${text} b", "${text}", "%0"),
    "a %0 b",
    "edge: %0 as replacement"
  )

  -- Replacement with %1 (gsub would treat as capture 1)
  assert_eq(
    safe_replace_all("a ${text} b", "${text}", "%1"),
    "a %1 b",
    "edge: %1 as replacement"
  )

  -- Very long replacement with many %
  local long_pct = string.rep("%d %s %f ", 100)
  local result = safe_replace_all(">${text}<", "${text}", long_pct)
  assert_eq(result, ">" .. long_pct .. "<",
    "edge: long string with many % chars")

  -- Newlines in replacement
  local multiline = "line1\nline2\nline3"
  assert_eq(
    safe_replace_all("before ${text} after", "${text}", multiline),
    "before line1\nline2\nline3 after",
    "edge: multiline replacement"
  )

  -- Target appears at very start and end
  assert_eq(
    safe_replace_all("${text}mid${text}", "${text}", "X"),
    "XmidX",
    "edge: target at boundaries"
  )
end

-- ============================================
-- 9. Verify gsub would fail on these cases
-- ============================================
io.write("\n--- Verify gsub failures ---\n")

do
  -- This section verifies that the standard gsub would fail or produce
  -- wrong results for cases our safe_replace handles correctly.

  local test_cases = {
    { name = "%d", replacement = 'print("%d" % 42)' },
    { name = "%s", replacement = 'format("%s")' },
    { name = "%0", replacement = "match: %0" },
    { name = "%1", replacement = "capture: %1" },
    { name = "%9", replacement = "capture: %9" },
  }

  for _, tc in ipairs(test_cases) do
    local gsub_ok, gsub_result = pcall(function()
      return string.gsub("X", "X", tc.replacement)
    end)

    local safe_result = safe_replace("X", "X", tc.replacement)

    if not gsub_ok then
      -- gsub crashed
      assert_eq(safe_result, tc.replacement,
        string.format("gsub-vs-safe/%s: gsub crashes, safe_replace works", tc.name))
    elseif gsub_result ~= tc.replacement then
      -- gsub produced wrong result
      assert_true(safe_result == tc.replacement,
        string.format("gsub-vs-safe/%s: gsub wrong (%q), safe correct (%q)",
          tc.name, gsub_result, safe_result))
    else
      -- gsub happened to work (some versions of Lua may handle %d differently)
      record("PASS",
        string.format("gsub-vs-safe/%s: both work for this case", tc.name))
    end
  end
end

-- ============================================
-- 10. Full template assembly with problematic code
-- ============================================
io.write("\n--- Full template assembly tests ---\n")

do
  local template = "echo -e | ${runner} <<EOF\n${text}\nEOF"

  -- Realistic Python with % formatting
  local python_code = [[
import sys
name = sys.argv[1] if len(sys.argv) > 1 else "World"
print("Hello, %s!" % name)
print("Answer: %d" % 42)
print("Pi: %.4f" % 3.14159)
print("100%%")
]]

  local result = safe_replace_all(template, "${runner}", "python3")
  result = safe_replace_all(result, "${text}", python_code)

  assert_true(result:find('print("Hello, %s!" % name)', 1, true) ~= nil,
    "full-template: Python %s preserved in assembled command")
  assert_true(result:find('print("Answer: %d" % 42)', 1, true) ~= nil,
    "full-template: Python %d preserved in assembled command")
  assert_true(result:find('print("Pi: %.4f" % 3.14159)', 1, true) ~= nil,
    "full-template: Python %.4f preserved in assembled command")
  assert_true(result:find('print("100%%")', 1, true) ~= nil,
    "full-template: Python %% (literal double-percent) preserved in assembled command")
end

do
  -- Nushell template
  local template = "COMMANDS=$(cat<<EOF\n${text}\nEOF\n);${runner} --commands $COMMANDS --no-newline"

  local nu_code = 'let pct = 42; $"($pct)%"'
  local result = safe_replace_all(template, "${runner}", "nu")
  result = safe_replace_all(result, "${text}", nu_code)

  -- The result should contain the nushell code with % intact
  -- Use string indexing to verify the % character is preserved
  local expected_nu_fragment = '($pct)%"'
  assert_true(result:find(expected_nu_fragment, 1, true) ~= nil,
    "full-template-nu: nushell % preserved")
  assert_true(result:find("nu --commands", 1, true) ~= nil,
    "full-template-nu: runner correctly substituted")
end

-- ============================================
-- Summary
-- ============================================
io.write("\n========================================\n")
io.write(string.format("  GSUB SPECIAL CHARS: %d passed, %d failed\n", pass_count, fail_count))
io.write("========================================\n\n")

-- Write results to file
local results_file = test_dir .. "/results_gsub_special_chars.txt"
local f = io.open(results_file, "w")
if f then
  f:write(string.format("gsub special chars test results\n"))
  f:write(string.format("Date: %s\n", os.date()))
  f:write(string.format("Total: %d passed, %d failed\n\n", pass_count, fail_count))
  for _, r in ipairs(results) do
    f:write(r .. "\n")
  end
  f:close()
end

if fail_count > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
