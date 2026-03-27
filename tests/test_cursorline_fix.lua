-- Test for Issue #43: Snack Picker CursorLine visibility
--
-- Runtime test that loads the real config, opens a picker, and verifies
-- the CursorLine highlight behavior at the Neovim API level.
--
-- Run: nvim --headless -u config.nvim/init.lua +"luafile tests/test_cursorline_fix.lua"
-- Results written to /tmp/test_cursorline_results.txt
--
-- What this tests:
--   1. Global CursorLine is transparent (dracula theme design)
--   2. SnacksPickerListCursorLine has a visible background
--   3. The picker list window uses SnacksPickerListCursorLine in winhighlight
--   4. CursorLineNoneEmpty links to Visual (non-transparent)

local results_file = "/tmp/test_cursorline_results.txt"
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

-- Helper: check if a highlight group has a visible background
local function has_visible_bg(hl_name)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
  return hl.bg ~= nil
end

-- Helper: get resolved bg color
local function get_bg(hl_name)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
  if hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

log("=== Issue #43: Snack Picker CursorLine Runtime Tests ===")
log("")

-- Phase 1: Theme highlight tests (no picker needed)
vim.defer_fn(function()
  log("[Phase 1] Theme highlight groups")

  -- Test 1: Global CursorLine should be transparent (this is the dracula design)
  local cursor_line_hl = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
  assert_test(
    "CursorLine is transparent (empty bg)",
    cursor_line_hl.bg == nil,
    "bg = " .. tostring(cursor_line_hl.bg)
  )

  -- Test 2: CursorLineNoneEmpty should link to Visual
  local cne_hl = vim.api.nvim_get_hl(0, { name = "CursorLineNoneEmpty", link = true })
  assert_test(
    "CursorLineNoneEmpty links to Visual",
    cne_hl.link == "Visual",
    "link = " .. tostring(cne_hl.link)
  )

  -- Test 3: Visual should have a visible background
  assert_test(
    "Visual has visible background",
    has_visible_bg("Visual"),
    "bg = " .. tostring(get_bg("Visual"))
  )

  -- Phase 2: Open a picker and test runtime behavior
  log("")
  log("[Phase 2] Picker runtime highlight tests")

  -- Create a temp file so the picker has something to show
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  for i = 1, 5 do
    local tmpf = io.open(tmpdir .. "/file" .. i .. ".txt", "w")
    if tmpf then tmpf:write("test " .. i) tmpf:close() end
  end

  local picker_ok, picker_err = pcall(function()
    Snacks.picker.files({ cwd = tmpdir })
  end)

  if not picker_ok then
    log("  ERROR: Failed to open picker: " .. tostring(picker_err))
    log("")
    log(string.format("=== Results: %d passed, %d failed ===", passed, failed))
    f:close()
    vim.cmd("qa!")
    return
  end

  -- Wait for picker to fully initialize
  vim.defer_fn(function()
    -- Test 4: SnacksPickerListCursorLine should exist and have a visible bg
    assert_test(
      "SnacksPickerListCursorLine has visible background",
      has_visible_bg("SnacksPickerListCursorLine"),
      "bg = " .. tostring(get_bg("SnacksPickerListCursorLine"))
    )

    -- Test 5: SnacksPickerListCursorLine bg should match Visual bg
    local picker_cl_bg = get_bg("SnacksPickerListCursorLine")
    local visual_bg = get_bg("Visual")
    assert_test(
      "SnacksPickerListCursorLine bg matches Visual bg",
      picker_cl_bg == visual_bg,
      "SnacksPickerListCursorLine=" .. tostring(picker_cl_bg) .. " Visual=" .. tostring(visual_bg)
    )

    -- Test 6: Find the picker list window and check its winhighlight
    local list_win = nil
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(w)
      local ft = vim.bo[buf].filetype
      if ft == "snacks_picker_list" then
        list_win = w
        break
      end
    end

    assert_test(
      "Picker list window exists",
      list_win ~= nil,
      "Could not find snacks_picker_list window"
    )

    if list_win then
      local whl = vim.wo[list_win].winhighlight
      -- The winhighlight should contain CursorLine:SnacksPickerListCursorLine
      local has_mapping = whl:find("CursorLine:SnacksPickerListCursorLine") ~= nil
      assert_test(
        "List window winhighlight maps CursorLine to SnacksPickerListCursorLine",
        has_mapping,
        "winhighlight = " .. tostring(whl)
      )

      -- Test 7: cursorline should be enabled in the list window
      local cl_enabled = vim.wo[list_win].cursorline
      assert_test(
        "List window has cursorline enabled",
        cl_enabled == true,
        "cursorline = " .. tostring(cl_enabled)
      )
    end

    -- Cleanup
    vim.fn.delete(tmpdir, "rf")

    -- Summary
    log("")
    log(string.format("=== Results: %d passed, %d failed ===", passed, failed))
    f:close()

    if failed > 0 then
      vim.cmd("cq!")  -- exit with error code
    else
      vim.cmd("qa!")
    end
  end, 3000)
end, 3000)
