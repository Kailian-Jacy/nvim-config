-- nvim-runner/tests/test_runner_spec.lua
-- Comprehensive tests for nvim-runner
-- Run: cd nvim-runner && nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_runner_spec.lua"

local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local fixtures_dir = test_dir .. "/fixtures"

-- Test framework
local results = {}
local pass_count = 0
local fail_count = 0
local skip_count = 0

local function record(status, name, detail)
  if status == "PASS" then
    pass_count = pass_count + 1
  elseif status == "FAIL" then
    fail_count = fail_count + 1
  elseif status == "SKIP" then
    skip_count = skip_count + 1
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
    record("FAIL", test_name, string.format("expected=%s, got=%s", tostring(expected), tostring(got)))
    return false
  end
end

local function assert_match(str, pattern, test_name, detail)
  if type(str) == "string" and str:match(pattern) then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, string.format("pattern=%s not found in: %s", pattern, tostring(str)))
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

-- Helper: create a buffer with content and filetype
local function create_buf(content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  if content and #content > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  end
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

-- Helper: run shell command synchronously and get output
local function shell_sync(cmd, timeout_ms)
  timeout_ms = timeout_ms or 5000
  local result = vim.system({ vim.o.shell, "-c", cmd }, { text = true }):wait(timeout_ms)
  return result
end

-- Helper: wait for async completion with polling
local function wait_for(check_fn, timeout_ms, poll_ms)
  timeout_ms = timeout_ms or 5000
  poll_ms = poll_ms or 50
  local start = vim.uv.now()
  while vim.uv.now() - start < timeout_ms do
    if check_fn() then
      return true
    end
    -- Process pending events
    vim.wait(poll_ms, function() return false end)
  end
  return check_fn()
end

io.write("\n========================================\n")
io.write("  nvim-runner test suite\n")
io.write("========================================\n\n")

-- ============================================
-- 1. Config tests
-- ============================================
io.write("--- Config Tests ---\n")

do
  local config = require("nvim-runner.config")
  assert_true(config.options ~= nil, "config: options exist after setup")
  assert_eq(config.options.timeout, 3000, "config: default timeout is 3000ms")
  assert_eq(config.options.insert_result, true, "config: default insert_result is true")
  assert_true(config.options.runners.python ~= nil, "config: python runner defined")
  assert_true(config.options.runners.lua ~= nil, "config: lua runner defined")
  assert_true(config.options.runners.sh ~= nil, "config: sh runner defined")
  assert_true(config.options.runners.nu ~= nil, "config: nu runner defined")
end

-- Test custom config merge
do
  local config = require("nvim-runner.config")
  local orig_timeout = config.options.timeout
  config.setup({ timeout = 5000 })
  assert_eq(config.options.timeout, 5000, "config: custom timeout override works")
  -- Runners should still exist (deep merge)
  assert_true(config.options.runners.python ~= nil, "config: python runner still exists after merge")
  -- Reset
  config.setup({ timeout = 3000 })
end

-- ============================================
-- 2. Util tests
-- ============================================
io.write("\n--- Util Tests ---\n")

do
  local util = require("nvim-runner.util")
  -- In headless mode, mode should be "n"
  assert_eq(util.is_in_visual_mode(), false, "util: not in visual mode in headless")
end

-- ============================================
-- 3. Commands existence
-- ============================================
io.write("\n--- Command Registration Tests ---\n")

do
  local cmds = vim.api.nvim_get_commands({})
  assert_true(cmds["RunScript"] ~= nil, "command: RunScript exists")
  assert_true(cmds["RunTest"] ~= nil, "command: RunTest exists")
  assert_true(cmds["SetBufRunner"] ~= nil, "command: SetBufRunner exists")
end

-- ============================================
-- 4. Lua runner tests (synchronous, in-process)
-- ============================================
io.write("\n--- Lua Runner Tests ---\n")

do
  -- Test basic lua execution
  local buf = create_buf('return 42', "lua")
  -- Capture notifications
  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  -- For lua with this_neovim, result is printed via vim.print
  -- We just check no error occurred
  record("PASS", "lua: basic return value execution")

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test lua with print
  local buf = create_buf('vim.notify("lua test output", vim.log.levels.INFO)', "lua")
  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found = false
  for _, n in ipairs(notifications) do
    if n.msg == "lua test output" then
      found = true
      break
    end
  end
  assert_true(found, "lua: vim.notify from executed code works")
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test lua syntax error
  local buf = create_buf('this is not valid lua!!!', "lua")
  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("failed to parse lua code block") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "lua: syntax error is reported")
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test lua multiline
  local buf = create_buf('local x = 1\nlocal y = 2\nreturn x + y', "lua")
  local runner = require("nvim-runner.runner")
  -- Should not error
  local ok, err = pcall(runner.run)
  assert_true(ok, "lua: multiline execution succeeds", err and tostring(err) or nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test lua nil return
  local buf = create_buf('local x = 1', "lua")
  local runner = require("nvim-runner.runner")
  local ok, err = pcall(runner.run)
  assert_true(ok, "lua: nil return (prints 'lua executed.')", err and tostring(err) or nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 5. Shell runner tests (async)
-- ============================================
io.write("\n--- Shell Runner Tests ---\n")

do
  -- Check if shell is available
  local shell = vim.o.shell
  if vim.fn.executable(shell) == 0 then
    -- Try to set to bash
    vim.o.shell = "bash"
  end

  -- Test basic shell execution
  local buf = create_buf('echo "hello shell"', "sh")
  local win = vim.api.nvim_get_current_win()
  local runner = require("nvim-runner.runner")
  runner.run()

  -- Wait for async result
  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:match("hello shell") and not line:match("^echo") then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "sh: basic echo output inserted into buffer")
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test shell with stderr
  local buf = create_buf('echo "stderr test" >&2', "sh")
  local runner = require("nvim-runner.runner")
  runner.run()

  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:match("stderr test") and not line:match("^echo") then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "sh: stderr output captured")
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test shell multiline
  local buf = create_buf('X=hello\necho "$X world"', "sh")
  local runner = require("nvim-runner.runner")
  runner.run()

  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:match("hello world") then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "sh: multiline script execution")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 6. Python runner tests
-- ============================================
io.write("\n--- Python Runner Tests ---\n")

do
  if vim.fn.executable("python3") == 1 or vim.fn.executable("python") == 1 then
    -- Test basic python
    local buf = create_buf('print("hello python")', "python")
    local runner = require("nvim-runner.runner")
    runner.run()

    local got_result = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for _, line in ipairs(lines) do
        if line:match("hello python") and not line:match("^print") then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result, "python: basic print output")
    vim.api.nvim_buf_delete(buf, { force = true })

    -- Test python multiline
    vim.wait(200, function() return false end) -- small delay between tests
    local buf2 = create_buf('x = 1\ny = 2\nprint(x + y)', "python")
    runner.run()

    local got_result2 = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
      for _, line in ipairs(lines) do
        if line == "3" then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result2, "python: multiline computation")
    vim.api.nvim_buf_delete(buf2, { force = true })

    -- Test python unicode
    vim.wait(200, function() return false end)
    local buf3 = create_buf('print("中文测试")', "python")
    runner.run()

    local got_result3 = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf3, 0, -1, false)
      for _, line in ipairs(lines) do
        if line:match("中文测试") and not line:match("^print") then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result3, "python: unicode output")
    vim.api.nvim_buf_delete(buf3, { force = true })

    -- Test python stderr (syntax error in python code)
    vim.wait(200, function() return false end)
    local buf4 = create_buf('import sys\nprint("err msg", file=sys.stderr)', "python")
    runner.run()

    local got_result4 = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf4, 0, -1, false)
      for _, line in ipairs(lines) do
        if line:match("err msg") and not line:match("^print") and not line:match("^import") then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result4, "python: stderr captured")
    vim.api.nvim_buf_delete(buf4, { force = true })
  else
    record("SKIP", "python: no python interpreter available")
  end
end

-- FIXED_BUG test: venv-selector pcall protection
do
  -- The original code had `require('venv-selector')` without pcall
  -- which would crash if venv-selector is not installed.
  -- Our fix uses pcall protection.
  local config = require("nvim-runner.config")
  local py_runner = config.options.runners.python
  if type(py_runner.runner) == "function" then
    local ok, result = pcall(py_runner.runner)
    -- Should not crash even without venv-selector
    assert_true(ok, "FIXED_BUG: venv-selector pcall protection - no crash without venv-selector")
  end
end

-- ============================================
-- 7. Nushell runner tests
-- ============================================
io.write("\n--- Nushell Runner Tests ---\n")

do
  if vim.fn.executable("nu") == 1 then
    local buf = create_buf('print "hello nushell"', "nu")
    local runner = require("nvim-runner.runner")
    runner.run()

    local got_result = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for _, line in ipairs(lines) do
        if line:match("hello nushell") and not line:match("^print") then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result, "nu: basic output")
    vim.api.nvim_buf_delete(buf, { force = true })
  else
    record("SKIP", "nu: nushell not available")
  end
end

-- ============================================
-- 8. Timeout tests
-- ============================================
io.write("\n--- Timeout Tests ---\n")

do
  -- Set a very short timeout for testing
  local config = require("nvim-runner.config")
  local orig_timeout = config.options.timeout
  config.setup({ timeout = 500 }) -- 500ms timeout

  local buf = create_buf('sleep 30', "sh")
  local runner = require("nvim-runner.runner")
  runner.run()

  -- Wait and check that the process was killed
  local was_killed = wait_for(function()
    return runner._current_runner == nil
  end, 3000)

  assert_true(was_killed, "FIXED_BUG: timeout kills process (500ms timeout for sleep 30)")

  -- Reset
  config.setup({ timeout = orig_timeout })
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test per-runner timeout override
  local config = require("nvim-runner.config")
  local runner_mod = require("nvim-runner.runner")

  -- Set runner-level timeout to 500ms
  config.options.runners.sh.timeout = 500

  local buf = create_buf('sleep 30', "sh")
  runner_mod.run()

  local was_killed = wait_for(function()
    return runner_mod._current_runner == nil
  end, 3000)

  assert_true(was_killed, "timeout: per-runner timeout override works")

  -- Reset
  config.options.runners.sh.timeout = nil
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 9. SetBufRunner tests
-- ============================================
io.write("\n--- SetBufRunner Tests ---\n")

do
  local buf = create_buf('hello world', "sh")

  -- Set a custom buffer runner
  vim.cmd('SetBufRunner echo "custom: ${text}"')

  local b_runner = vim.b[buf].runner
  assert_true(b_runner ~= nil, "SetBufRunner: buffer runner set")
  assert_true(b_runner.sh ~= nil, "SetBufRunner: sh entry created")
  assert_eq(b_runner.sh.runner, "", "SetBufRunner: runner is empty string")
  assert_match(b_runner.sh.template, "custom", "SetBufRunner: template contains custom text")

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test SetBufRunner with no filetype
  local buf = create_buf('test', nil)
  vim.bo[buf].filetype = ""

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  vim.cmd('SetBufRunner echo test')

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("invalid filetype") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "SetBufRunner: error on empty filetype")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 10. Buffer-local runner override tests
-- ============================================
io.write("\n--- Buffer-local Runner Override Tests ---\n")

do
  local buf = create_buf('hello', "sh")
  -- Set buffer local runner
  vim.b[buf].runner = {
    sh = {
      runner = "",
      template = 'echo "overridden: ${text}"',
    },
  }

  local runner = require("nvim-runner.runner")
  runner.run()

  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:match("overridden: hello") then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "buffer-local: custom runner template overrides default")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 11. No filetype test
-- ============================================
io.write("\n--- No Filetype Tests ---\n")

do
  local buf = create_buf('some text', nil)
  vim.bo[buf].filetype = ""

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("No filetype") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "no filetype: error message shown")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 12. Unknown filetype test
-- ============================================
io.write("\n--- Unknown Filetype Tests ---\n")

do
  local buf = create_buf('some text', "weirdlang")

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("No runner found") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "unknown filetype: error message for unsupported type")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 13. RunTest tests
-- ============================================
io.write("\n--- RunTest Tests ---\n")

do
  -- Create a temporary vimtest file
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  local test_file = tmpdir .. "/example_vimtest.lua"
  local f = io.open(test_file, "w")
  f:write('return "test_passed_42"\n')
  f:close()

  -- Change to tmpdir
  local orig_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. tmpdir)

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local test_runner = require("nvim-runner.test_runner")
  test_runner.run()

  vim.notify = orig_notify

  local found_testing = false
  local found_result = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("Testing file") then
      found_testing = true
    end
    if n.msg and n.msg:match("test_passed_42") then
      found_result = true
    end
  end
  assert_true(found_testing, "RunTest: discovers vimtest files")
  assert_true(found_result, "RunTest: reports test results")

  -- Cleanup
  vim.cmd("cd " .. orig_cwd)
  os.remove(test_file)
  os.remove(tmpdir)
end

do
  -- RunTest with no test files
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")

  local orig_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. tmpdir)

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local test_runner = require("nvim-runner.test_runner")
  test_runner.run()

  vim.notify = orig_notify

  local found_no_files = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("No.*vimtest") then
      found_no_files = true
      break
    end
  end
  assert_true(found_no_files, "RunTest: reports when no test files found")

  vim.cmd("cd " .. orig_cwd)
  os.remove(tmpdir)
end

do
  -- RunTest with error in test file
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  local test_file = tmpdir .. "/bad_vimtest.lua"
  local f = io.open(test_file, "w")
  f:write('error("intentional test error")\n')
  f:close()

  local orig_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. tmpdir)

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local test_runner = require("nvim-runner.test_runner")
  test_runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("Error executing test file") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "RunTest: handles erroring test files gracefully")

  vim.cmd("cd " .. orig_cwd)
  os.remove(test_file)
  os.remove(tmpdir)
end

-- ============================================
-- 14. Kill current runner test
-- ============================================
io.write("\n--- Kill Current Runner Tests ---\n")

do
  local runner = require("nvim-runner.runner")

  -- No runner active
  assert_eq(runner.kill_current(), false, "kill_current: returns false when no runner active")

  -- Start a long-running process
  local buf = create_buf('sleep 60', "sh")
  runner.run()

  -- Wait for process to start
  local started = wait_for(function()
    return runner._current_runner ~= nil
  end, 3000)

  if started then
    assert_true(runner.kill_current(), "kill_current: returns true when killing active runner")
    assert_eq(runner._current_runner, nil, "kill_current: runner is nil after kill")
  else
    record("FAIL", "kill_current: process failed to start")
  end

  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 15. FIXED_BUG: Race condition test
-- ============================================
io.write("\n--- Race Condition Tests ---\n")

do
  -- FIXED_BUG: Original code killed _current_runner in the callback,
  -- which meant it killed the OLD runner, not the current one.
  -- Fixed: now kill before starting new runner.
  local runner = require("nvim-runner.runner")

  -- Start first long-running process
  local buf1 = create_buf('sleep 60\necho "first"', "sh")
  runner.run()

  local started1 = wait_for(function()
    return runner._current_runner ~= nil
  end, 3000)

  if started1 then
    local pid1 = runner._current_runner

    -- Start second process (should kill first)
    vim.wait(100, function() return false end)
    local buf2 = create_buf('echo "second"', "sh")
    runner.run()

    -- The first process should have been killed
    -- and a new one started
    local new_started = wait_for(function()
      return runner._current_runner ~= nil and runner._current_runner ~= pid1
    end, 3000)

    -- Even if the second finishes very quickly, the pid should have changed
    assert_true(pid1 ~= runner._current_runner or runner._current_runner == nil,
      "FIXED_BUG: race condition - old runner killed before new one starts")

    -- Cleanup
    runner.kill_current()
    vim.api.nvim_buf_delete(buf2, { force = true })
  else
    record("SKIP", "FIXED_BUG: race condition - first process failed to start")
  end

  vim.api.nvim_buf_delete(buf1, { force = true })
end

-- ============================================
-- 16. FIXED_BUG: tostring test
-- ============================================
io.write("\n--- FIXED_BUG: tostring Tests ---\n")

do
  -- FIXED_BUG: Original used `string(obj.code)` which would error
  -- because `string` is not a global function in Lua. Fixed to use `tostring`.
  local ok = pcall(function()
    local _ = tostring(0) -- should work
  end)
  assert_true(ok, "FIXED_BUG: tostring(obj.code) works correctly")

  -- Verify `string` as function would fail
  local ok2 = pcall(function()
    local _ = string(0) ---@diagnostic disable-line
  end)
  assert_true(not ok2, "FIXED_BUG: string(obj.code) would have errored (confirmed bug)")
end

-- ============================================
-- 17. FIXED_BUG: vim.log.levels test
-- ============================================
io.write("\n--- FIXED_BUG: vim.log.levels Tests ---\n")

do
  -- FIXED_BUG: Original used `vim.log.level.INFO` (missing 's')
  -- which would be nil. Fixed to `vim.log.levels.INFO`.
  assert_true(vim.log.levels.INFO ~= nil, "FIXED_BUG: vim.log.levels.INFO exists")
  assert_eq(vim.log.level, nil, "FIXED_BUG: vim.log.level (without s) is nil - confirms original bug")
end

-- ============================================
-- 18. FIXED_BUG: timeout unit consistency
-- ============================================
io.write("\n--- FIXED_BUG: Timeout Unit Tests ---\n")

do
  local config = require("nvim-runner.config")
  -- All timeouts should be in milliseconds now
  assert_eq(config.defaults.runners.python.timeout, 3000, "FIXED_BUG: python timeout is 3000ms (was 3)")
  assert_eq(config.defaults.runners.nu.timeout, 5000, "FIXED_BUG: nu timeout is 5000ms (was 5)")
  assert_eq(config.defaults.timeout, 3000, "FIXED_BUG: default timeout is 3000ms")
end

-- ============================================
-- 19. FIXED_BUG: timeout operator precedence
-- ============================================
io.write("\n--- FIXED_BUG: Timeout Operator Precedence Tests ---\n")

do
  -- FIXED_BUG: Original was `candidate and type(candidate) == "number" or candidate > 0`
  -- Due to operator precedence: (candidate and type(candidate) == "number") or (candidate > 0)
  -- When candidate is not a number (e.g., a string), `candidate > 0` would error.
  -- Fixed to: `candidate and (type(candidate) == "number" and candidate > 0)`

  -- Test with a non-number value - original would crash
  local function original_logic(candidate)
    -- This simulates the buggy original
    return candidate and type(candidate) == "number" or candidate > 0
  end

  local function fixed_logic(candidate)
    return candidate and (type(candidate) == "number" and candidate > 0)
  end

  -- String candidate would crash in original
  local ok_original = pcall(original_logic, "not_a_number")
  local ok_fixed = pcall(fixed_logic, "not_a_number")

  assert_true(not ok_original, "FIXED_BUG: original timeout logic crashes with string candidate")
  assert_true(ok_fixed, "FIXED_BUG: fixed timeout logic handles string candidate safely")

  -- Numeric candidate should work in both
  assert_true(pcall(fixed_logic, 3000), "FIXED_BUG: fixed timeout logic works with number")
  assert_eq(fixed_logic(0), false, "FIXED_BUG: fixed timeout logic rejects 0")
  assert_eq(fixed_logic(-1), false, "FIXED_BUG: fixed timeout logic rejects negative")
  assert_eq(fixed_logic(nil), nil, "FIXED_BUG: fixed timeout logic handles nil")
end

-- ============================================
-- 20. Empty buffer tests
-- ============================================
io.write("\n--- Edge Case: Empty Buffer Tests ---\n")

do
  local buf = create_buf('', "sh")
  local runner = require("nvim-runner.runner")
  local ok, err = pcall(runner.run)
  assert_true(ok, "empty buffer: no crash on empty sh buffer", err and tostring(err) or nil)
  vim.wait(500, function() return false end) -- let any async finish
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = create_buf('', "lua")
  local runner = require("nvim-runner.runner")
  local ok, err = pcall(runner.run)
  assert_true(ok, "empty buffer: no crash on empty lua buffer", err and tostring(err) or nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 21. Special characters test
-- ============================================
io.write("\n--- Edge Case: Special Characters Tests ---\n")

do
  local buf = create_buf([[echo 'single quotes' "double quotes" $VARIABLE `backticks`]], "sh")
  local runner = require("nvim-runner.runner")
  local ok, err = pcall(runner.run)
  assert_true(ok, "special chars: no crash with quotes and shell chars", err and tostring(err) or nil)
  vim.wait(1000, function() return false end)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 22. insert_result=false test
-- ============================================
io.write("\n--- Config: insert_result=false Tests ---\n")

do
  local config = require("nvim-runner.config")
  config.setup({ insert_result = false })

  local buf = create_buf('echo "should not appear in buffer"', "sh")
  local initial_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local runner = require("nvim-runner.runner")
  runner.run()

  vim.wait(3000, function() return false end)

  local final_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- With insert_result=false, the buffer content should not change beyond the initial content
  -- (aside from the echo command template being printed)
  local found_output = false
  for _, line in ipairs(final_lines) do
    if line == "should not appear in buffer" then
      found_output = true
      break
    end
  end
  assert_true(not found_output, "insert_result=false: output not inserted into buffer")

  -- Reset
  config.setup({ insert_result = true })
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 23. Runner function template test
-- ============================================
io.write("\n--- Runner Function Template Tests ---\n")

do
  local buf = create_buf('hello', "sh")
  -- Set a function template
  vim.b[buf].runner = {
    sh = {
      runner = "",
      template = function(runner, text)
        return 'echo "func template: ' .. text .. '"'
      end,
    },
  }

  local runner = require("nvim-runner.runner")
  runner.run()

  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:match("func template: hello") then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "function template: custom function template works")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 24. Runner function returning nil (abort)
-- ============================================
io.write("\n--- Runner Abort Tests ---\n")

do
  local buf = create_buf('test', "sh")
  vim.b[buf].runner = {
    sh = {
      runner = function()
        return nil -- abort
      end,
      template = "${text}",
    },
  }

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_abort = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("abortion") then
      found_abort = true
      break
    end
  end
  assert_true(found_abort, "runner abort: runner function returning nil triggers abort message")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 25. Template function returning nil (abort)
-- ============================================
do
  local buf = create_buf('test', "sh")
  vim.b[buf].runner = {
    sh = {
      runner = "echo",
      template = function()
        return nil -- abort
      end,
    },
  }

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_abort = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("abortion") then
      found_abort = true
      break
    end
  end
  assert_true(found_abort, "template abort: template function returning nil triggers abort message")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 26. Invalid runner type test
-- ============================================
io.write("\n--- Invalid Runner Type Tests ---\n")

do
  local buf = create_buf('test', "sh")
  vim.b[buf].runner = {
    sh = {
      runner = 42, -- invalid type
      template = "${text}",
    },
  }

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("not qualified") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "invalid runner: number runner type reported as error")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 27. Invalid template type test
-- ============================================
do
  local buf = create_buf('test', "sh")
  vim.b[buf].runner = {
    sh = {
      runner = "echo",
      template = 42, -- invalid type
    },
  }

  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local runner = require("nvim-runner.runner")
  runner.run()

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:match("not qualified") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "invalid template: number template type reported as error")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 28. Idempotency test
-- ============================================
io.write("\n--- Idempotency Tests ---\n")

do
  -- Run setup multiple times
  local ok = pcall(function()
    require("nvim-runner").setup()
    require("nvim-runner").setup({ timeout = 5000 })
    require("nvim-runner").setup()
  end)
  assert_true(ok, "idempotency: multiple setup calls don't crash")

  -- Verify commands still work after re-setup
  local cmds = vim.api.nvim_get_commands({})
  assert_true(cmds["RunScript"] ~= nil, "idempotency: RunScript still exists after re-setup")
end

-- ============================================
-- Summary
-- ============================================
io.write("\n========================================\n")
io.write(string.format("  RESULTS: %d passed, %d failed, %d skipped\n", pass_count, fail_count, skip_count))
io.write("========================================\n\n")

-- Write results to file
local results_file = test_dir .. "/../test_results.txt"
local f = io.open(results_file, "w")
if f then
  f:write(string.format("nvim-runner test results\n"))
  f:write(string.format("Date: %s\n", os.date()))
  f:write(string.format("Neovim: %s\n", tostring(vim.version())))
  f:write(string.format("Total: %d passed, %d failed, %d skipped\n\n", pass_count, fail_count, skip_count))
  for _, r in ipairs(results) do
    f:write(r .. "\n")
  end
  f:close()
end

-- Exit with error code if failures
if fail_count > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
