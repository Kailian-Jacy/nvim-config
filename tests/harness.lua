-- Test Harness for Neovim Config E2E Tests
-- Usage: nvim --headless -u config.nvim/init.lua +"luafile tests/test_xxx.lua" +qa 2>&1

local M = {}

M.results = {
  pass = 0,
  fail = 0,
  skip = 0,
  known_bug = 0,
  details = {},
}

-- Known bugs from code review (02-code-review.md)
M.known_bugs = {
  ["P32"] = "vim.fn.has() returns 0/1 not boolean, all platforms detected as MACOS",
  ["P3-FlipPinnedTab"] = "FlipPinnedTab typo: last_lab → last_tab",
  ["P4-bookmarks"] = "bookmarks.nvim enable → enabled + condition expression error",
  ["P5-RunScript"] = "RunScript timeout logic: or → and",
  ["P6-SvnDiffShiftVersion"] = "SvnDiffShiftVersion overrides opts object",
  ["P7-string"] = "string() → tostring()",
}

function M.test(id, description, fn, known_bug_id)
  local ok, err = pcall(fn)
  if ok then
    M.results.pass = M.results.pass + 1
    table.insert(M.results.details, string.format("PASS | %s | %s", id, description))
    io.write(string.format("PASS | %s | %s\n", id, description))
  else
    if known_bug_id and M.known_bugs[known_bug_id] then
      M.results.known_bug = M.results.known_bug + 1
      table.insert(M.results.details, string.format("KNOWN_BUG | %s | %s | Bug: %s | Error: %s", id, description, known_bug_id, tostring(err)))
      io.write(string.format("KNOWN_BUG | %s | %s | %s\n", id, description, known_bug_id))
    else
      M.results.fail = M.results.fail + 1
      table.insert(M.results.details, string.format("FAIL | %s | %s | Error: %s", id, description, tostring(err)))
      io.write(string.format("FAIL | %s | %s | %s\n", id, description, tostring(err)))
    end
  end
end

function M.skip(id, description, reason)
  M.results.skip = M.results.skip + 1
  table.insert(M.results.details, string.format("SKIP | %s | %s | Reason: %s", id, description, reason))
  io.write(string.format("SKIP | %s | %s | %s\n", id, description, reason))
end

function M.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s (%s), got %s (%s)",
      msg or "assertion failed",
      tostring(expected), type(expected),
      tostring(actual), type(actual)))
  end
end

function M.assert_true(val, msg)
  if not val then
    error(msg or "expected truthy value, got " .. tostring(val))
  end
end

function M.assert_false(val, msg)
  if val then
    error(msg or "expected falsy value, got " .. tostring(val))
  end
end

function M.assert_contains(str, substr, msg)
  if type(str) ~= "string" then
    error((msg or "assert_contains") .. ": expected string, got " .. type(str) .. " = " .. tostring(str))
  end
  if not str:find(substr, 1, true) then
    error(string.format("%s: '%s' not found in '%s'", msg or "assert_contains", substr, str))
  end
end

function M.assert_not_empty(str, msg)
  if type(str) ~= "string" or str == "" then
    error(msg or "expected non-empty string, got " .. tostring(str))
  end
end

function M.assert_type(val, expected_type, msg)
  if type(val) ~= expected_type then
    error(string.format("%s: expected type %s, got %s", msg or "type check", expected_type, type(val)))
  end
end

function M.maparg_exists(lhs, mode)
  local m = vim.fn.maparg(lhs, mode or "n")
  return m ~= nil and m ~= ""
end

function M.maparg_contains(lhs, mode, substr)
  local m = vim.fn.maparg(lhs, mode or "n")
  if type(m) ~= "string" or m == "" then return false end
  return m:find(substr, 1, true) ~= nil
end

-- Check if a mapping exists (including function mappings)
function M.mapping_exists(lhs, mode)
  mode = mode or "n"
  local maps = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(maps) do
    if map.lhs == lhs or map.lhs == lhs:gsub(" ", "<Space>") then
      return true
    end
  end
  -- Also check buffer-local
  local ok, buf_maps = pcall(vim.api.nvim_buf_get_keymap, 0, mode)
  if ok then
    for _, map in ipairs(buf_maps) do
      if map.lhs == lhs or map.lhs == lhs:gsub(" ", "<Space>") then
        return true
      end
    end
  end
  return false
end

function M.summary()
  local total = M.results.pass + M.results.fail + M.results.skip + M.results.known_bug
  local summary = string.format(
    "\n========================================\n" ..
    "TEST SUMMARY\n" ..
    "========================================\n" ..
    "Total:     %d\n" ..
    "Pass:      %d\n" ..
    "Fail:      %d\n" ..
    "Known Bug: %d\n" ..
    "Skip:      %d\n" ..
    "========================================\n",
    total, M.results.pass, M.results.fail, M.results.known_bug, M.results.skip
  )
  io.write(summary)
  return summary
end

function M.get_report()
  local lines = {}
  for _, detail in ipairs(M.results.details) do
    table.insert(lines, detail)
  end
  table.insert(lines, M.summary())
  return table.concat(lines, "\n")
end

return M
