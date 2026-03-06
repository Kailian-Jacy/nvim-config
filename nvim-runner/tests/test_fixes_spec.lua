-- nvim-runner/tests/test_fixes_spec.lua
-- Tests for review fixes: keymap dedup, buffer/window validity, timeout API
--
-- Run: cd nvim-runner && nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_fixes_spec.lua"

local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

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

-- Helper: wait for async completion with polling
local function wait_for(check_fn, timeout_ms, poll_ms)
  timeout_ms = timeout_ms or 5000
  poll_ms = poll_ms or 50
  local start = vim.uv.now()
  while vim.uv.now() - start < timeout_ms do
    if check_fn() then
      return true
    end
    vim.wait(poll_ms, function() return false end)
  end
  return check_fn()
end

io.write("\n========================================\n")
io.write("  nvim-runner fixes test suite\n")
io.write("========================================\n\n")

-- ============================================
-- 1. Keymap deduplication on re-setup
-- ============================================
io.write("--- Keymap Dedup Tests ---\n")

do
  local M = require("nvim-runner")

  -- Setup with test keymaps
  M.setup({ keymaps = { run = "<leader>tr" } })

  -- Verify keymap exists
  local keymaps = vim.api.nvim_get_keymap("n")
  local count1 = 0
  for _, km in ipairs(keymaps) do
    if km.lhs == " tr" or km.lhs == "<Leader>tr" or km.lhs == "\\tr" then
      count1 = count1 + 1
    end
  end
  assert_true(count1 >= 1, "keymap-dedup: keymap registered after first setup")

  -- Re-setup with same keymaps
  M.setup({ keymaps = { run = "<leader>tr" } })

  -- Count keymaps again - should NOT be doubled
  keymaps = vim.api.nvim_get_keymap("n")
  local count2 = 0
  for _, km in ipairs(keymaps) do
    if km.lhs == " tr" or km.lhs == "<Leader>tr" or km.lhs == "\\tr" then
      count2 = count2 + 1
    end
  end
  assert_eq(count2, count1, "keymap-dedup: keymap count unchanged after re-setup")

  -- Setup third time
  M.setup({ keymaps = { run = "<leader>tr" } })
  keymaps = vim.api.nvim_get_keymap("n")
  local count3 = 0
  for _, km in ipairs(keymaps) do
    if km.lhs == " tr" or km.lhs == "<Leader>tr" or km.lhs == "\\tr" then
      count3 = count3 + 1
    end
  end
  assert_eq(count3, count1, "keymap-dedup: keymap count unchanged after third setup")

  -- Clean up: re-setup with different keymaps
  M.setup({ keymaps = { run = "<leader>xx" } })

  -- Old keymap should be gone
  keymaps = vim.api.nvim_get_keymap("n")
  local old_found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == " tr" or km.lhs == "<Leader>tr" or km.lhs == "\\tr" then
      old_found = true
    end
  end
  assert_true(not old_found, "keymap-dedup: old keymaps removed when changing keys")

  -- Cleanup
  M.setup({ keymaps = { run = { "<c-s-cr>", "<d-s-cr>" } } })
end

do
  -- Test _registered_keymaps tracking
  local M = require("nvim-runner")
  M.setup({ keymaps = { run = { "<leader>a1", "<leader>a2" } } })
  assert_true(M._registered_keymaps ~= nil, "keymap-dedup: _registered_keymaps exists")
  assert_eq(#M._registered_keymaps, 2, "keymap-dedup: _registered_keymaps has 2 entries")

  -- Reset
  M.setup({ keymaps = { run = { "<c-s-cr>", "<d-s-cr>" } } })
end

-- ============================================
-- 2. Buffer/Window validity in async callback
-- ============================================
io.write("\n--- Buffer/Window Validity Tests ---\n")

do
  -- Test: buffer closed while script is running
  local buf = create_buf('sleep 0.5 && echo "done"', "sh")
  local runner = require("nvim-runner.runner")

  -- Start the script
  runner.run()

  -- Wait for it to start
  local started = wait_for(function()
    return runner._current_runner ~= nil
  end, 2000)

  if started then
    -- Close the buffer while running
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(new_buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })

    -- Capture notifications
    local notifications = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
      -- Call original for visibility
    end

    -- Wait for the script to finish
    local finished = wait_for(function()
      return runner._current_runner == nil
    end, 5000)

    vim.notify = orig_notify

    assert_true(finished, "buf-validity: script finished after buffer closed")

    -- Check that a notification was issued about the closed buffer
    local found_warning = false
    for _, n in ipairs(notifications) do
      if n.msg and (n.msg:find("buffer 已关闭") or n.msg:find("新 buffer")) then
        found_warning = true
        break
      end
    end
    -- The warning is only shown when insert_result=true (default)
    assert_true(found_warning, "buf-validity: warned about closed buffer")

    -- Cleanup
    pcall(vim.api.nvim_buf_delete, new_buf, { force = true })
  else
    record("SKIP", "buf-validity: script failed to start")
  end
end

do
  -- Test: no crash when buffer is deleted (the main safety check)
  local buf = create_buf('sleep 0.3 && echo "safety_test"', "sh")
  local runner = require("nvim-runner.runner")
  runner.run()

  local started = wait_for(function()
    return runner._current_runner ~= nil
  end, 2000)

  if started then
    -- Force delete the buffer
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(new_buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })

    -- Should not crash
    local ok = true
    local finished = wait_for(function()
      -- Process events, checking for errors
      local status, err = pcall(function()
        vim.wait(50, function() return false end)
      end)
      if not status then
        ok = false
      end
      return runner._current_runner == nil
    end, 5000)

    assert_true(ok, "buf-validity: no crash when buffer deleted during execution")
    pcall(vim.api.nvim_buf_delete, new_buf, { force = true })
  else
    record("SKIP", "buf-validity: script failed to start for safety test")
  end
end

-- ============================================
-- 3. Timeout API — buffer-local / global
-- ============================================
io.write("\n--- Timeout API Tests ---\n")

do
  local M = require("nvim-runner")
  local config = require("nvim-runner.config")
  local runner = require("nvim-runner.runner")

  -- Test set_timeout API
  M.setup({ timeout = 3000 })
  assert_eq(config.options.timeout, 3000, "timeout-api: default is 3000")

  M.set_timeout(5000)
  assert_eq(config.options.timeout, 5000, "timeout-api: set_timeout changes global timeout")

  -- Test invalid values
  local ok1 = pcall(M.set_timeout, -1)
  assert_true(not ok1, "timeout-api: set_timeout rejects negative value")

  local ok2 = pcall(M.set_timeout, 0)
  assert_true(not ok2, "timeout-api: set_timeout rejects zero")

  local ok3 = pcall(M.set_timeout, "abc")
  assert_true(not ok3, "timeout-api: set_timeout rejects string")

  -- Reset
  M.set_timeout(3000)
end

do
  local M = require("nvim-runner")

  -- Test set_buf_timeout API
  local buf = create_buf("test", "sh")
  M.set_buf_timeout(buf, 7000)
  assert_eq(vim.b[buf].runner_timeout, 7000, "timeout-api: set_buf_timeout sets vim.b.runner_timeout")

  -- Test with bufnr=0 (current buffer)
  M.set_buf_timeout(0, 8000)
  assert_eq(vim.b[buf].runner_timeout, 8000, "timeout-api: set_buf_timeout with 0 uses current buffer")

  -- Test invalid values
  local ok1 = pcall(M.set_buf_timeout, buf, -1)
  assert_true(not ok1, "timeout-api: set_buf_timeout rejects negative value")

  -- Test vim.b.runner_timeout directly
  vim.b[buf].runner_timeout = 9000
  assert_eq(vim.b[buf].runner_timeout, 9000, "timeout-api: vim.b.runner_timeout settable directly")

  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 4. Timeout priority: buf-local > runner > global > default
-- ============================================
io.write("\n--- Timeout Priority Tests ---\n")

do
  local runner = require("nvim-runner.runner")
  local config = require("nvim-runner.config")

  -- resolve_timeout is exposed for testing
  local resolve = runner._resolve_timeout

  -- Setup
  config.setup({ timeout = 4000 })
  local buf = create_buf("test", "sh")

  -- Case 1: no runner timeout, no buf timeout → global (4000)
  local t1 = resolve({ template = "${text}" }, buf)
  assert_eq(t1, 4000, "timeout-priority: falls back to global timeout")

  -- Case 2: runner timeout set → runner timeout wins
  local t2 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t2, 6000, "timeout-priority: runner timeout overrides global")

  -- Case 3: buf-local timeout set → buf-local wins
  vim.b[buf].runner_timeout = 2000
  local t3 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t3, 2000, "timeout-priority: buffer-local timeout overrides runner timeout")

  -- Case 4: buf-local removed → falls back to runner
  vim.b[buf].runner_timeout = nil
  local t4 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t4, 6000, "timeout-priority: without buf-local, falls back to runner")

  -- Case 5: invalid buf-local (not a number) → skip to runner
  vim.b[buf].runner_timeout = "invalid"
  local t5 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t5, 6000, "timeout-priority: non-number buf-local skipped")

  -- Case 6: zero buf-local → skip to runner
  vim.b[buf].runner_timeout = 0
  local t6 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t6, 6000, "timeout-priority: zero buf-local skipped")

  -- Case 7: negative buf-local → skip to runner
  vim.b[buf].runner_timeout = -1
  local t7 = resolve({ template = "${text}", timeout = 6000 }, buf)
  assert_eq(t7, 6000, "timeout-priority: negative buf-local skipped")

  -- Case 8: no runner timeout, no global → default 3000
  config.options.timeout = nil
  vim.b[buf].runner_timeout = nil
  local t8 = resolve({ template = "${text}" }, buf)
  assert_eq(t8, 3000, "timeout-priority: falls back to default 3000ms")

  -- Reset
  config.setup({ timeout = 3000 })
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 5. RunnerTimeout command
-- ============================================
io.write("\n--- RunnerTimeout Command Tests ---\n")

do
  -- Check command exists
  local cmds = vim.api.nvim_get_commands({})
  assert_true(cmds["RunnerTimeout"] ~= nil, "RunnerTimeout: command exists")
end

do
  -- Buffer-local (no bang)
  local buf = create_buf("test", "sh")
  vim.cmd("RunnerTimeout 5000")
  assert_eq(vim.b[buf].runner_timeout, 5000, "RunnerTimeout: sets buffer-local timeout")

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Global (with bang)
  local config = require("nvim-runner.config")
  local orig = config.options.timeout
  vim.cmd("RunnerTimeout! 7000")
  assert_eq(config.options.timeout, 7000, "RunnerTimeout!: sets global timeout")
  -- Reset
  config.options.timeout = orig
end

do
  -- Invalid value
  local notifications = {}
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  local buf = create_buf("test", "sh")
  vim.cmd("RunnerTimeout abc")

  vim.notify = orig_notify

  local found_error = false
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:find("invalid") then
      found_error = true
      break
    end
  end
  assert_true(found_error, "RunnerTimeout: error on invalid value")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 6. Timeout actually works with new priority
-- ============================================
io.write("\n--- Timeout Integration Tests ---\n")

do
  -- Test that buffer-local timeout actually controls kill timing
  local M = require("nvim-runner")
  local runner = require("nvim-runner.runner")
  local config = require("nvim-runner.config")

  -- Set global timeout very long (10s)
  config.setup({ timeout = 10000 })

  -- Create buffer with short buf-local timeout
  local buf = create_buf('sleep 30', "sh")
  vim.b[buf].runner_timeout = 500

  runner.run()

  -- Process should be killed within ~500ms, not 10s
  local was_killed = wait_for(function()
    return runner._current_runner == nil
  end, 3000)

  assert_true(was_killed, "timeout-integration: buffer-local timeout (500ms) overrides global (10s)")

  -- Reset
  config.setup({ timeout = 3000 })
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- 7. safe_replace used in runner (integration)
-- ============================================
io.write("\n--- safe_replace Integration Tests ---\n")

do
  -- Test that Python code with % actually works end-to-end
  if vim.fn.executable("python3") == 1 or vim.fn.executable("python") == 1 then
    local code = 'print("%d items" % 5)'
    local buf = create_buf(code, "python")
    local runner = require("nvim-runner.runner")
    runner.run()

    local got_result = wait_for(function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for _, line in ipairs(lines) do
        if line == "5 items" then
          return true
        end
      end
      return false
    end, 8000)

    assert_true(got_result, "safe_replace-integration: Python % formatting works end-to-end")
    vim.api.nvim_buf_delete(buf, { force = true })
  else
    record("SKIP", "safe_replace-integration: no python available")
  end
end

do
  -- Test shell with % in printf
  local code = 'printf "Score: %d%%\\n" 95'
  local buf = create_buf(code, "sh")
  local runner = require("nvim-runner.runner")
  runner.run()

  local got_result = wait_for(function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line == "Score: 95%" then
        return true
      end
    end
    return false
  end, 5000)

  assert_true(got_result, "safe_replace-integration: Shell printf with % works")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- Summary
-- ============================================
io.write("\n========================================\n")
io.write(string.format("  FIXES: %d passed, %d failed, %d skipped\n", pass_count, fail_count, skip_count))
io.write("========================================\n\n")

-- Write results to file
local results_file = test_dir .. "/results_fixes.txt"
local f = io.open(results_file, "w")
if f then
  f:write(string.format("nvim-runner fixes test results\n"))
  f:write(string.format("Date: %s\n", os.date()))
  f:write(string.format("Total: %d passed, %d failed, %d skipped\n\n", pass_count, fail_count, skip_count))
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
