-- Tests for bigfile consolidation (#57)
-- Verifies:
--   1. LunarVim/bigfile.nvim is no longer referenced
--   2. NoMatchParen is wrapped in vim.schedule in both files
--   3. Binary detection autocmd group exists
--   4. BigFileInfo/BigFileOverride commands exist
--   5. Snacks bigfile setup callback is properly configured

local ok_count = 0
local fail_count = 0
local total = 0

local function check(desc, condition)
  total = total + 1
  if condition then
    ok_count = ok_count + 1
    print("  ✓ " .. desc)
  else
    fail_count = fail_count + 1
    print("  ✗ " .. desc)
  end
end

-- Helper: read file content
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

-- Determine repo root (script may be run from repo root or tests/ dir)
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local repo_root = script_dir:match("(.-)tests/") or script_dir .. "../"

local bigfile_path = repo_root .. "config.nvim/lua/plugins/bigfile.lua"
local misc_path = repo_root .. "config.nvim/lua/plugins/miscellaneous.lua"

print("\n=== Test: bigfile consolidation (#57) ===\n")

-- 1. LunarVim/bigfile.nvim is no longer referenced in bigfile.lua
print("[1] LunarVim/bigfile.nvim removal")
local bigfile_content = read_file(bigfile_path)
assert(bigfile_content, "Could not read " .. bigfile_path)

check("bigfile.lua does not reference LunarVim/bigfile.nvim",
  not bigfile_content:find("LunarVim/bigfile%.nvim"))

check("bigfile.lua does not require('bigfile')",
  not bigfile_content:find('require%("bigfile"%)'))

check("bigfile.lua does not call bigfile.setup()",
  not bigfile_content:find('require%("bigfile"%).setup'))

-- 2. NoMatchParen is wrapped in vim.schedule
print("\n[2] NoMatchParen in vim.schedule (core fix for E201)")

-- In bigfile.lua: NoMatchParen must appear inside a vim.schedule block
local bigfile_schedule_block = bigfile_content:match("vim%.schedule%(function%(%).-NoMatchParen.-end%)")
check("bigfile.lua: NoMatchParen is inside vim.schedule(function()...end)",
  bigfile_schedule_block ~= nil)

-- Verify there's no bare/synchronous NoMatchParen call outside vim.schedule
-- Count all NoMatchParen occurrences and all that are inside vim.schedule
local all_nomatchparen = {}
for pos in bigfile_content:gmatch("()NoMatchParen") do
  table.insert(all_nomatchparen, pos)
end
-- Every NoMatchParen in bigfile.lua should be either in a comment or inside vim.schedule
local bare_calls = 0
for _, pos in ipairs(all_nomatchparen) do
  -- Get the line containing this occurrence
  local line_start = bigfile_content:sub(1, pos):match(".*\n()") or 1
  local line_end = bigfile_content:find("\n", pos) or #bigfile_content
  local line = bigfile_content:sub(line_start, line_end)
  -- Skip comments
  if not line:match("^%s*%-%-") then
    -- Check if it's inside a vim.schedule block (look backwards for vim.schedule)
    local before = bigfile_content:sub(math.max(1, pos - 200), pos)
    if not before:match("vim%.schedule%(function%(%)\n") then
      bare_calls = bare_calls + 1
    end
  end
end
check("bigfile.lua: no bare (non-scheduled) NoMatchParen calls",
  bare_calls == 0)

-- In miscellaneous.lua: same check
local misc_content = read_file(misc_path)
assert(misc_content, "Could not read " .. misc_path)

local misc_schedule_block = misc_content:match("vim%.schedule%(function%(%).-NoMatchParen.-end%)")
check("miscellaneous.lua: NoMatchParen is inside vim.schedule(function()...end)",
  misc_schedule_block ~= nil)

-- 3. Binary detection autocmd exists
print("\n[3] Binary file detection")
check("bigfile.lua has binary_file_detection augroup",
  bigfile_content:find('"binary_file_detection"') ~= nil)

check("bigfile.lua has BufReadPost autocmd for binary detection",
  bigfile_content:find('BufReadPost') ~= nil)

check("bigfile.lua has binary_extensions table",
  bigfile_content:find('binary_extensions') ~= nil)

check("bigfile.lua has is_binary_content function",
  bigfile_content:find('function is_binary_content') ~= nil)

-- 4. User commands exist
print("\n[4] User commands")
check("bigfile.lua defines BigFileInfo command",
  bigfile_content:find('"BigFileInfo"') ~= nil)

check("bigfile.lua defines BigFileOverride command",
  bigfile_content:find('"BigFileOverride"') ~= nil)

-- 5. Snacks bigfile setup callback
print("\n[5] Snacks bigfile configuration")
check("miscellaneous.lua has Snacks bigfile setup function",
  misc_content:find('setup = function%(ctx%)') ~= nil)

check("miscellaneous.lua has bigfile size = 1024 * 1024",
  misc_content:find('size = 1024 %* 1024') ~= nil)

check("miscellaneous.lua disables copilot in bigfile setup",
  misc_content:find('copilot_enabled = false') ~= nil)

check("miscellaneous.lua restores syntax in vim.schedule",
  misc_content:find('vim%.bo%[ctx%.buf%]%.syntax = ctx%.ft') ~= nil)

-- 6. BufReadPre precheck
print("\n[6] BufReadPre precheck")
check("bigfile.lua has bigfile_precheck augroup",
  bigfile_content:find('"bigfile_precheck"') ~= nil)

check("bigfile.lua has BufReadPre autocmd",
  bigfile_content:find('BufReadPre') ~= nil)

-- 7. Lazy.nvim spec format
print("\n[7] Lazy.nvim plugin spec format")
check("bigfile.lua returns a table (plugin spec)",
  bigfile_content:match("^return {") ~= nil or bigfile_content:match("\nreturn {") ~= nil)

check("bigfile.lua uses dir-based spec (no external plugin URL)",
  bigfile_content:find('dir = vim%.fn%.stdpath') ~= nil)

-- Summary
print(string.format("\n=== Results: %d/%d passed ===", ok_count, total))
if fail_count > 0 then
  print(string.format("FAILED: %d test(s) failed!", fail_count))
  os.exit(1)
else
  print("ALL TESTS PASSED!")
  os.exit(0)
end
