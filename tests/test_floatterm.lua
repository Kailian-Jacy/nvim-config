-- Minimal tests for floatterm module
-- Run: nvim --headless -u NONE -c "lua dofile('tests/test_floatterm.lua')"

local passed = 0
local failed = 0

local function assert_eq(got, expected, msg)
  if got == expected then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(string.format("FAIL: %s\n  expected: %s\n  got: %s\n", msg, tostring(expected), tostring(got)))
  end
end

local function assert_true(val, msg)
  assert_eq(val, true, msg)
end

local function assert_nil(val, msg)
  if val == nil then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(string.format("FAIL: %s\n  expected nil, got: %s\n", msg, tostring(val)))
  end
end

-- Add module path
package.path = "config.nvim/lua/?.lua;" .. "config.nvim/lua/?/init.lua;" .. package.path

-- Mock vim globals needed by modules
if not vim then
  -- Running outside neovim - we need to stub
  print("ERROR: Must run inside nvim --headless")
  os.exit(1)
end

-- Setup minimal vim.g values
vim.g.floatterm_global_session = "nvim-global"
vim.g.floatterm_local_prefix = "nvim-local-"
vim.g.terminal_auto_insert = false  -- disable for testing

print("=== FloatTerm Unit Tests ===\n")

-------------------------------------------------------------
-- Test 1: State management
-------------------------------------------------------------
print("--- State Management ---")

local state = require("config.floatterm.state")
state:reset()

-- Global starts empty
assert_nil(state.global.bufnr, "global bufnr initially nil")
assert_eq(state.global.slot, "centered", "global slot default centered")
assert_eq(state.global.visible, false, "global not visible initially")

-- Local instance creation
local loc1 = state:get_local()
assert_eq(loc1.slot, "centered", "local slot default centered")
assert_eq(loc1.visible, false, "local not visible initially")

-- Same tab returns same instance
local loc2 = state:get_local()
assert_eq(loc1, loc2, "same tab returns same local instance")

-------------------------------------------------------------
-- Test 2: Slot occupant logic
-------------------------------------------------------------
print("\n--- Slot Occupant ---")

state:reset()

-- No occupant initially
assert_nil(state:slot_occupant("centered"), "no occupant at centered initially")
assert_nil(state:slot_occupant("left"), "no occupant at left initially")

-- Simulate global visible at centered (but winid invalid since no real window)
state.global.visible = true
state.global.slot = "centered"
state.global.winid = nil
-- Without valid winid, no occupant reported
assert_nil(state:slot_occupant("centered"), "no occupant without valid winid")

-------------------------------------------------------------
-- Test 3: Window geometry calculation
-------------------------------------------------------------
print("\n--- Window Geometry ---")

local window = require("config.floatterm.window")

-- Set known dimensions
vim.o.columns = 200
vim.o.lines = 50

local centered = window.get_geometry("centered")
assert_eq(centered.relative, "editor", "centered relative=editor")
assert_eq(centered.width, math.floor(200 * 0.96), "centered width")
assert_eq(centered.height, math.floor(49 * 0.92), "centered height")

local left = window.get_geometry("left")
assert_eq(left.relative, "editor", "left relative=editor")
assert_eq(left.col, 0, "left col=0")
assert_eq(left.width, math.floor(200 * 0.4), "left width 40%")

local right = window.get_geometry("right")
assert_eq(right.relative, "editor", "right relative=editor")
assert_eq(right.width, math.floor(200 * 0.4), "right width 40%")
assert_true(right.col > 0, "right col > 0")

-------------------------------------------------------------
-- Test 4: Tmux session naming
-------------------------------------------------------------
print("\n--- Tmux Naming ---")

local tmux = require("config.floatterm.tmux")

-- Global session name
assert_eq(tmux.global_session_name(), "nvim-global", "global session name")

-- Local session name based on cwd
-- Mock cwd
local orig_getcwd = vim.fn.getcwd
vim.fn.getcwd = function() return "/home/user/projects/my.project" end

local name = tmux.session_name_for_tab()
assert_eq(name, "nvim-local-projects_my_project", "local session: dots replaced, last 2 segments")

vim.fn.getcwd = function() return "/tmp" end
name = tmux.session_name_for_tab()
assert_eq(name, "nvim-local-tmp", "local session: single segment")

vim.fn.getcwd = function() return "/home/user/code:special" end
name = tmux.session_name_for_tab()
assert_eq(name, "nvim-local-user_code_special", "local session: colons replaced")

vim.fn.getcwd = orig_getcwd

-------------------------------------------------------------
-- Test 5: Toggle semantics (integration-style)
-------------------------------------------------------------
print("\n--- Toggle Semantics ---")

-- Reset and test toggle logic without spawning real terminals
state:reset()
local ft = require("config.floatterm")

-- Test is_terminal_buffer
vim.bo.buftype = ""
assert_eq(ft.is_terminal_buffer(), false, "non-terminal buffer detected")

-- Test get_focused_terminal when nothing is open
local inst, kind = ft.get_focused_terminal()
assert_nil(inst, "no focused terminal when none open")
assert_nil(kind, "no kind when none open")

-------------------------------------------------------------
-- Summary
-------------------------------------------------------------
print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
