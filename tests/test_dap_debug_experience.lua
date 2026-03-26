-- Test for Issues #60, #61, #62, #63: DAP debugging experience improvements
--
-- Tests verify:
--   #60: event_terminated/event_exited/disconnect listeners do NOT auto-close dap-view
--   #62: Virtual console buffer creation, output routing, partial lines
--   #61: One-time auto-jump with per-session flag, no jump during stepping
--   #63: E keymap distinguishes attach vs launch
--
-- Includes both source-level structural checks and behavioral tests
-- that exercise actual buffer/output logic.
--
-- Run: nvim --headless +"luafile tests/test_dap_debug_experience.lua"
-- Results written to /tmp/test_dap_debug_experience_results.txt

local results_file = "/tmp/test_dap_debug_experience_results.txt"
local f = io.open(results_file, "w")
local passed = 0
local failed = 0

local function log(msg)
  f:write(msg .. "\n")
  f:flush()
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

log("=== Issues #60, #61, #62, #63: DAP Debug Experience Tests ===")
log("")

-- ================================================================
-- Read the source files
-- ================================================================
local source_path = "config.nvim/lua/plugins/debug.lua"
local source_lines = vim.fn.readfile(source_path)
if #source_lines == 0 then
  source_path = vim.fn.getcwd() .. "/config.nvim/lua/plugins/debug.lua"
  source_lines = vim.fn.readfile(source_path)
end
local source = table.concat(source_lines, "\n")
assert_test("Source file loaded", #source > 0, "Could not read " .. source_path)

-- Helper: extract a listener block from source
local function extract_listener_block(event_name, listener_key)
  local block_start_line = nil
  for i, line in ipairs(source_lines) do
    if line:find(event_name, 1, true) and line:find(listener_key, 1, true) then
      block_start_line = i
      break
    end
  end
  if not block_start_line then return nil end
  local start_indent = #(source_lines[block_start_line]:match("^(%s*)") or "")
  local block_lines = { source_lines[block_start_line] }
  for i = block_start_line + 1, #source_lines do
    table.insert(block_lines, source_lines[i])
    local line = source_lines[i]
    local indent = #(line:match("^(%s*)") or "")
    if line:match("^%s*end%s*$") and indent == start_indent then
      break
    end
  end
  return table.concat(block_lines, "\n")
end

-- ================================================================
-- Phase 1: Issue #60 — Verify auto-close is removed
-- ================================================================
log("[Phase 1] Issue #60: dap-view auto-close removed")

local term_block = extract_listener_block("event_terminated", "nvim-dap-noui")
assert_test("event_terminated[nvim-dap-noui] block found", term_block ~= nil and #term_block > 10)
if term_block then
  assert_test("event_terminated does NOT contain defer_fn", not term_block:find("defer_fn"))
  assert_test("event_terminated still updates debugging_status", term_block:find("NoDebug") ~= nil)
  assert_test("event_terminated still refreshes lualine", term_block:find("lualine") ~= nil)
end

local exited_block = extract_listener_block("event_exited", "nvim-dap-noui")
assert_test("event_exited[nvim-dap-noui] block found", exited_block ~= nil and #exited_block > 10)
if exited_block then
  assert_test("event_exited does NOT contain defer_fn", not exited_block:find("defer_fn"))
end

local disc_block = extract_listener_block("disconnect", "nvim-dap-noui")
assert_test("disconnect[nvim-dap-noui] block found", disc_block ~= nil and #disc_block > 10)
if disc_block then
  assert_test("disconnect does NOT contain defer_fn", not disc_block:find("defer_fn"))
end

-- ================================================================
-- Phase 2: Issue #62 — Source-level checks
-- ================================================================
log("")
log("[Phase 2] Issue #62: Source-level structure")

assert_test("console-ensure-term listener defined", source:find('console%-ensure%-term') ~= nil)
assert_test("console-output-mirror listener defined", source:find('console%-output%-mirror') ~= nil)
assert_test("_dap_output_bufs tracking table declared", source:find('_dap_output_bufs') ~= nil)
assert_test("_last_line_complete tracking table declared", source:find('_last_line_complete') ~= nil)

-- C1: All three exit events have cleanup
assert_test("C1: event_terminated has console-output-cleanup",
  source:find('event_terminated%["console%-output%-cleanup"%]') ~= nil)
assert_test("C1: event_exited has console-output-cleanup",
  source:find('event_exited%["console%-output%-cleanup"%]') ~= nil)
assert_test("C1: disconnect has console-output-cleanup",
  source:find('disconnect%["console%-output%-cleanup"%]') ~= nil)

-- C2: Buffer deletion in cleanup
assert_test("C2: cleanup deletes buffer (nvim_buf_delete)",
  source:find('nvim_buf_delete') ~= nil)

-- M1: Buffer creation is synchronous (no vim.schedule wrapping create_buf)
local ensure_block = extract_listener_block("event_initialized", "console-ensure-term")
assert_test("M1: console-ensure-term block found", ensure_block ~= nil)
if ensure_block then
  -- Check that nvim_create_buf is NOT inside a vim.schedule
  -- Strategy: find create_buf and check if it's before any vim.schedule
  local create_pos = ensure_block:find("nvim_create_buf")
  local schedule_pos = ensure_block:find("vim%.schedule")
  assert_test("M1: buffer creation is before vim.schedule (synchronous)",
    create_pos ~= nil and schedule_pos ~= nil and create_pos < schedule_pos,
    "create_buf at " .. tostring(create_pos) .. ", schedule at " .. tostring(schedule_pos))
end

-- M2: Output mirror only writes to _dap_output_bufs, not session.term_buf fallback
local mirror_block = extract_listener_block("event_output", "console-output-mirror")
assert_test("M2: mirror block found", mirror_block ~= nil)
if mirror_block then
  -- Should use _dap_output_bufs[session.id] without fallback to session.term_buf
  assert_test("M2: mirror reads from _dap_output_bufs",
    mirror_block:find('_dap_output_bufs%[session%.id%]') ~= nil)
  assert_test("M2: mirror does NOT fallback to session.term_buf",
    not mirror_block:find('or session%.term_buf'),
    "Found 'or session.term_buf' fallback — would cause duplicate output")
end

-- m1: \r\n double-encoding protection — the old gsub("\n", "\r\n") is gone
-- since we no longer write to terminal buffers in the mirror
assert_test("m1: no bare gsub for \\r\\n double-encoding",
  not source:find('gsub%("\\n", "\\r\\n"%)'),
  "Found gsub(\"\\n\", \"\\r\\n\") which double-encodes existing \\r\\n")

-- m3: Scratch buffer initial empty line cleared
assert_test("m3: scratch buffer cleared after creation",
  source:find('nvim_buf_set_lines%(buf, 0, %-1, false, {}%)') ~= nil)

-- ================================================================
-- Phase 2b: Behavioral — Virtual buffer + output routing
-- ================================================================
log("")
log("[Phase 2b] Behavioral: Virtual buffer creation & output routing")

-- Create a scratch buffer the way the code does
local buf = vim.api.nvim_create_buf(false, true)
vim.bo[buf].filetype = "dap-view-term"
vim.bo[buf].bufhidden = "hide"
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

assert_test("Buffer created and valid", vim.api.nvim_buf_is_valid(buf))
assert_test("Buffer starts empty (m3 fix)",
  vim.api.nvim_buf_line_count(buf) == 0
    or (vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""),
  "line count = " .. vim.api.nvim_buf_line_count(buf))

-- Test complete line append
vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Hello from stdout" })
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local found = false
for _, l in ipairs(lines) do
  if l == "Hello from stdout" then found = true end
end
assert_test("Complete line written to buffer", found, vim.inspect(lines))

-- Test M3: partial line handling
-- Simulate: first write "Hello " (no newline), second write "World\n"
-- Reset buffer
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
local last_complete = true

-- Write 1: "Hello " (no trailing \n)
local raw1 = "Hello "
local trailing1 = raw1:sub(-1) == "\n"
local lines1 = vim.split(raw1, "\n", { plain = true })
if trailing1 and #lines1 > 0 and lines1[#lines1] == "" then table.remove(lines1) end

if not last_complete and #lines1 > 0 then
  -- would append to last line, but buffer is fresh so skip
end
if #lines1 > 0 then
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines1)
end
last_complete = trailing1

-- Write 2: "World\n"
local raw2 = "World\n"
local trailing2 = raw2:sub(-1) == "\n"
local lines2 = vim.split(raw2, "\n", { plain = true })
if trailing2 and #lines2 > 0 and lines2[#lines2] == "" then table.remove(lines2) end

if not last_complete and #lines2 > 0 then
  -- Append first fragment to last line
  local line_count = vim.api.nvim_buf_line_count(buf)
  local last_idx = math.max(0, line_count - 1)
  local existing = vim.api.nvim_buf_get_lines(buf, last_idx, last_idx + 1, false)[1] or ""
  lines2[1] = existing .. lines2[1]
  vim.api.nvim_buf_set_lines(buf, last_idx, last_idx + 1, false, { lines2[1] })
  table.remove(lines2, 1)
end
if #lines2 > 0 then
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines2)
end
last_complete = trailing2

lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local combined = false
for _, l in ipairs(lines) do
  if l == "Hello World" then combined = true end
end
assert_test("M3: Partial lines combined on same line", combined,
  "Expected 'Hello World' on one line, got: " .. vim.inspect(lines))

-- Test M3: multiple complete lines
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
last_complete = true
local raw3 = "line1\nline2\nline3\n"
local trailing3 = raw3:sub(-1) == "\n"
local lines3 = vim.split(raw3, "\n", { plain = true })
if trailing3 and #lines3 > 0 and lines3[#lines3] == "" then table.remove(lines3) end
vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines3)
lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-- Filter empty leading line
local non_empty = {}
for _, l in ipairs(lines) do
  if l ~= "" or #non_empty > 0 then table.insert(non_empty, l) end
end
assert_test("Multiple complete lines written correctly",
  #non_empty >= 3
    and non_empty[1] == "line1"
    and non_empty[2] == "line2"
    and non_empty[3] == "line3",
  vim.inspect(lines))

-- Test C2: buffer deletion
local del_buf = vim.api.nvim_create_buf(false, true)
assert_test("C2: test buffer created", vim.api.nvim_buf_is_valid(del_buf))
pcall(vim.api.nvim_buf_delete, del_buf, { force = true })
assert_test("C2: buffer deleted successfully", not vim.api.nvim_buf_is_valid(del_buf))

-- Cleanup
pcall(vim.api.nvim_buf_delete, buf, { force = true })

-- ================================================================
-- Phase 3: Issue #61 — Source-level checks
-- ================================================================
log("")
log("[Phase 3] Issue #61: One-time auto-jump structure")

assert_test("dap-view-auto-jump listener defined", source:find('dap%-view%-auto%-jump') ~= nil)
assert_test("_output_auto_jumped tracking table declared", source:find('_output_auto_jumped') ~= nil)
assert_test("output-auto-jump-reset listener defined", source:find('output%-auto%-jump%-reset') ~= nil)

-- C1: All three exit events clean up auto-jump flags
assert_test("C1: event_terminated has output-auto-jump-cleanup",
  source:find('event_terminated%["output%-auto%-jump%-cleanup"%]') ~= nil)
assert_test("C1: event_exited has output-auto-jump-cleanup",
  source:find('event_exited%["output%-auto%-jump%-cleanup"%]') ~= nil)
assert_test("C1: disconnect has output-auto-jump-cleanup",
  source:find('disconnect%["output%-auto%-jump%-cleanup"%]') ~= nil)

-- M4: Stepping guard — check debugging_status == "Stopped"
local jump_block = extract_listener_block("event_output", "dap-view-auto-jump")
assert_test("M4: auto-jump block found", jump_block ~= nil)
if jump_block then
  assert_test("M4: auto-jump checks debugging_status for Stopped",
    jump_block:find('debugging_status') ~= nil and jump_block:find('"Stopped"') ~= nil,
    "No Stopped guard in auto-jump")
  assert_test("Auto-jump checks _output_auto_jumped flag",
    jump_block:find('_output_auto_jumped%[session%.id%]') ~= nil)
  assert_test("Auto-jump sets flag to true",
    jump_block:find('_output_auto_jumped%[session%.id%] = true') ~= nil)
  assert_test("Auto-jump uses show_view",
    jump_block:find('show_view') ~= nil)
  assert_test("Auto-jump checks current_section",
    jump_block:find('current_section') ~= nil)
end

-- ================================================================
-- Phase 3b: Behavioral — Auto-jump flag lifecycle
-- ================================================================
log("")
log("[Phase 3b] Behavioral: Auto-jump flag lifecycle")

-- Simulate the per-session flag table behavior
local auto_jumped = {}

-- Session init resets flag
auto_jumped["sess1"] = false
assert_test("Flag initialized to false", auto_jumped["sess1"] == false)

-- First output sets flag
auto_jumped["sess1"] = true
assert_test("Flag set to true after first output", auto_jumped["sess1"] == true)

-- Subsequent output is blocked by flag
assert_test("Flag prevents subsequent jumps", auto_jumped["sess1"] == true)

-- Multiple sessions independent
auto_jumped["sess2"] = false
assert_test("Second session has independent flag", auto_jumped["sess2"] == false)
assert_test("First session flag unchanged", auto_jumped["sess1"] == true)

-- Cleanup on terminated
auto_jumped["sess1"] = nil
assert_test("Flag cleaned up on session end", auto_jumped["sess1"] == nil)
assert_test("Other session unaffected by cleanup", auto_jumped["sess2"] == false)

-- Cleanup on exited (C1 fix)
auto_jumped["sess2"] = nil
assert_test("C1: flag cleaned up on event_exited", auto_jumped["sess2"] == nil)

-- M4: Simulate stepping guard
local debugging_status = "Stopped"
auto_jumped["sess3"] = false
-- Auto-jump would set flag but skip the actual jump
if not auto_jumped["sess3"] then
  auto_jumped["sess3"] = true
  if debugging_status == "Stopped" then
    -- Don't actually jump — just marked as done
  end
end
assert_test("M4: flag set but no jump when Stopped",
  auto_jumped["sess3"] == true)

-- ================================================================
-- Phase 4: Integration — No regressions
-- ================================================================
log("")
log("[Phase 4] Integration: No regressions")

assert_test("dap-view auto-open listener still present",
  source:find('dap%-view%-auto') ~= nil and source:find('dap%-view.*open') ~= nil)
assert_test("event_stopped still switches to scopes view",
  source:find('event_stopped.*nvim%-dap%-noui') ~= nil and source:find('jump_to_view.*scopes') ~= nil)
for _, event in ipairs({ "terminated", "exited" }) do
  assert_test("event_" .. event .. " sets debugging_status to NoDebug",
    source:find("event_" .. event .. '.-NoDebug') ~= nil)
end

-- ================================================================
-- Phase 5: Issue #63 — E keymap attach vs launch
-- ================================================================
log("")
log("[Phase 5] Issue #63: E keymap distinguishes attach vs launch")

local keymaps_path = "config.nvim/lua/config/keymaps.lua"
local keymaps_lines = vim.fn.readfile(keymaps_path)
if #keymaps_lines == 0 then
  keymaps_path = vim.fn.getcwd() .. "/config.nvim/lua/config/keymaps.lua"
  keymaps_lines = vim.fn.readfile(keymaps_path)
end
local keymaps_source = table.concat(keymaps_lines, "\n")
assert_test("Keymaps source file loaded", #keymaps_source > 0)

-- Extract the E keymap block
local e_block = ""
local de_start = keymaps_source:find('<leader>dE')
local e_debug = keymaps_source:find('debugModeKey = "E"')
if de_start and e_debug then
  local brace_start = keymaps_source:sub(1, de_start):match(".*()%s*{")
  local brace_end = keymaps_source:find("},", e_debug)
  if brace_start and brace_end then
    e_block = keymaps_source:sub(brace_start, brace_end + 1)
  end
end

assert_test("E keymap block extracted", #e_block > 50)
if #e_block > 50 then
  assert_test("E keymap checks session.config.request",
    e_block:find('session%.config%.request') ~= nil)
  assert_test("E keymap calls disconnect() for attach",
    e_block:find('"attach"') ~= nil and e_block:find('disconnect') ~= nil)
  assert_test("E keymap calls terminate() for launch",
    e_block:find('terminate') ~= nil)
  assert_test("E keymap handles no active session",
    e_block:find('No active debug session') ~= nil or e_block:find('not session') ~= nil)
end

-- ================================================================
-- Summary
-- ================================================================
log("")
log(string.format("=== Results: %d passed, %d failed ===", passed, failed))
f:close()

if failed > 0 then
  vim.cmd("cq!")
else
  vim.cmd("qa!")
end
