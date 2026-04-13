-- benchmark_cursor_move.lua — Measure consecutive cursor movement latency
--
-- PURPOSE: Diagnose what's causing jjjj/kkkk lag by benchmarking N
--          consecutive cursor moves with different features toggled.
--
-- USAGE (inside your normal nvim with all plugins loaded):
--   :luafile tests/benchmark_cursor_move.lua
--
-- Or from shell:
--   nvim +"luafile tests/benchmark_cursor_move.lua" +"qa!" some_large_file.lua
--
-- The script measures two things for each scenario:
--   1. "autocmd" time  — vim.cmd("normal! j") without forced redraw
--      (captures CursorMoved handlers, plugin hooks, fold recalculation)
--   2. "render" time   — vim.cmd("normal! j") + vim.cmd("redraw!")
--      (captures everything including treesitter highlight, syntax, inlay hints)
--
-- The difference (render - autocmd) ≈ rendering overhead per move.

local N = 500            -- consecutive j-moves per test run
local ROUNDS = 3         -- repeat each scenario for stability
local MIN_LINES = 1200   -- ensure buffer has enough lines
local WARMUP = 20        -- warmup moves before measurement

--------------------------------------------------------------------------------
-- Buffer preparation
--------------------------------------------------------------------------------
local function ensure_lines(min_lines)
  local lines = vim.api.nvim_buf_line_count(0)
  if lines >= min_lines then return end
  local new = {}
  for i = 1, min_lines - lines do
    -- Realistic-looking code so treesitter/syntax actually work
    local templates = {
      ("local var_%d = { key = 'value', num = %d, flag = true }"):format(i, i),
      ("function module.func_%d(arg1, arg2)"):format(i),
      ("  if arg1 > %d then return arg2 + %d end"):format(i, i * 2),
      ("end -- func_%d"):format(i),
      ("-- TODO: refactor this section (%d)"):format(i),
      ("for k, v in pairs(tbl_%d) do table.insert(result, v) end"):format(i),
      ("local ok, err = pcall(require, 'module_%d')"):format(i),
      ("vim.api.nvim_create_autocmd('BufEnter', { callback = function() end })"),
    }
    new[i] = templates[(i % #templates) + 1]
  end
  vim.api.nvim_buf_set_lines(0, -1, -1, false, new)
  -- Give treesitter a moment to parse
  vim.cmd("doautocmd FileType")
  vim.wait(100)
end

--------------------------------------------------------------------------------
-- Core benchmark
--------------------------------------------------------------------------------

---@param n integer number of consecutive moves
---@param with_redraw boolean force redraw after each move
---@return number elapsed_ms
local function timed_moves(n, with_redraw)
  vim.cmd("normal! gg")
  -- warmup (populate caches, trigger lazy autocmds)
  for _ = 1, WARMUP do vim.cmd("normal! j") end
  if with_redraw then vim.cmd("redraw!") end
  vim.cmd("normal! gg")

  local start = vim.loop.hrtime()
  if with_redraw then
    for _ = 1, n do
      vim.cmd("normal! j")
      vim.cmd("redraw!")
    end
  else
    for _ = 1, n do
      vim.cmd("normal! j")
    end
  end
  return (vim.loop.hrtime() - start) / 1e6 -- ms
end

---@param n integer
---@param rounds integer
---@param label string
---@return table result {label, autocmd_ms, render_ms, ...}
local function run_scenario(n, rounds, label)
  local autocmd_times = {}
  local render_times = {}
  for r = 1, rounds do
    autocmd_times[r] = timed_moves(n, false)
    render_times[r] = timed_moves(n, true)
  end
  table.sort(autocmd_times)
  table.sort(render_times)
  local mid = math.ceil(rounds / 2)
  return {
    label = label,
    autocmd_median = autocmd_times[mid],
    render_median = render_times[mid],
    autocmd_per = autocmd_times[mid] / n,
    render_per = render_times[mid] / n,
    n = n,
  }
end

--------------------------------------------------------------------------------
-- Feature toggles — each returns a restore function
--------------------------------------------------------------------------------

local function try_disable(name, disable_fn)
  local ok, err = pcall(disable_fn)
  if not ok then
    vim.notify(("[bench] skip toggle '%s': %s"):format(name, err), vim.log.levels.DEBUG)
    return nil
  end
  return true
end

-- State captures for restore
local saved = {}

local toggles = {
  {
    name = "treesitter_hl",
    desc = "vim.treesitter highlight",
    disable = function()
      saved.ts = true
      vim.treesitter.stop(0)
    end,
    restore = function()
      if saved.ts then
        pcall(vim.treesitter.start, 0)
        saved.ts = nil
      end
    end,
  },
  {
    name = "vim_syntax",
    desc = "vim regex syntax",
    disable = function()
      saved.syntax = vim.bo.syntax
      vim.bo.syntax = "off"
    end,
    restore = function()
      if saved.syntax then
        vim.bo.syntax = saved.syntax
        saved.syntax = nil
      end
    end,
  },
  {
    name = "local_highlight",
    desc = "local-highlight.nvim",
    disable = function()
      local lh = require("local-highlight")
      -- The plugin provides a detach/clear per-buffer method
      if lh.detach then
        lh.detach(0)
      elseif lh.clear then
        lh.clear(0)
      end
      -- Also try to disable the autocmd group
      pcall(vim.cmd, "autocmd! LocalHighlight")
    end,
    restore = function()
      pcall(function()
        local lh = require("local-highlight")
        if lh.attach then lh.attach(0) end
      end)
    end,
  },
  {
    name = "scrollbar",
    desc = "nvim-scrollbar",
    disable = function()
      local sb = require("scrollbar")
      if sb.clear then sb.clear() end
      -- Disable handlers
      pcall(vim.cmd, "autocmd! ScrollbarHandleCursor")
      pcall(vim.cmd, "autocmd! Scrollbar")
      saved.scrollbar = true
    end,
    restore = function()
      if saved.scrollbar then
        pcall(function() require("scrollbar").render() end)
        saved.scrollbar = nil
      end
    end,
  },
  {
    name = "ufo",
    desc = "nvim-ufo folding",
    disable = function()
      local ufo = require("ufo")
      if ufo.disable then
        ufo.disable()
        saved.ufo = true
      end
    end,
    restore = function()
      if saved.ufo then
        pcall(function() require("ufo").enable() end)
        saved.ufo = nil
      end
    end,
  },
  {
    name = "inlay_hints",
    desc = "LSP inlay hints",
    disable = function()
      if vim.lsp.inlay_hint and vim.lsp.inlay_hint.is_enabled and vim.lsp.inlay_hint.is_enabled() then
        vim.lsp.inlay_hint.enable(false)
        saved.inlay = true
      end
    end,
    restore = function()
      if saved.inlay then
        pcall(vim.lsp.inlay_hint.enable, true)
        saved.inlay = nil
      end
    end,
  },
  {
    name = "vimade",
    desc = "vimade dimming",
    disable = function()
      pcall(vim.cmd, "VimadeDisable")
      saved.vimade = true
    end,
    restore = function()
      if saved.vimade then
        pcall(vim.cmd, "VimadeEnable")
        saved.vimade = nil
      end
    end,
  },
  {
    name = "noice",
    desc = "noice.nvim",
    disable = function()
      pcall(vim.cmd, "Noice disable")
      saved.noice = true
    end,
    restore = function()
      if saved.noice then
        pcall(vim.cmd, "Noice enable")
        saved.noice = nil
      end
    end,
  },
}

--------------------------------------------------------------------------------
-- Run the benchmark
--------------------------------------------------------------------------------
local function run_all()
  ensure_lines(MIN_LINES)
  vim.bo.filetype = vim.bo.filetype ~= "" and vim.bo.filetype or "lua"

  local results = {}
  local ft = vim.bo.filetype
  local line_count = vim.api.nvim_buf_line_count(0)

  -- Header
  print("══════════════════════════════════════════════════════════════")
  print(("  Cursor Movement Benchmark — %d consecutive j-moves × %d rounds"):format(N, ROUNDS))
  print(("  Buffer: %s (%d lines, ft=%s)"):format(
    vim.fn.expand("%:t") ~= "" and vim.fn.expand("%:t") or "[generated]",
    line_count, ft
  ))
  print("══════════════════════════════════════════════════════════════")
  print("")

  -- 1) Baseline — everything on
  print("⏱  Running: baseline (all features on)...")
  local baseline = run_scenario(N, ROUNDS, "baseline (all on)")
  table.insert(results, baseline)

  -- 2) Disable each feature individually
  for _, toggle in ipairs(toggles) do
    local ok = try_disable(toggle.name, toggle.disable)
    if ok then
      print(("⏱  Running: disable %s..."):format(toggle.desc))
      local r = run_scenario(N, ROUNDS, "− " .. toggle.desc)
      table.insert(results, r)
      toggle.restore()
      -- small pause to let things re-stabilize
      vim.wait(50)
    else
      print(("⏭  Skipped: %s (not loaded or error)"):format(toggle.desc))
    end
  end

  -- 3) Disable ALL at once (bare minimum)
  print("⏱  Running: all features disabled (bare nvim)...")
  local restorers = {}
  for _, toggle in ipairs(toggles) do
    local ok = try_disable(toggle.name, toggle.disable)
    if ok then table.insert(restorers, toggle.restore) end
  end
  local bare = run_scenario(N, ROUNDS, "ALL disabled (bare)")
  table.insert(results, bare)
  for _, restore in ipairs(restorers) do
    pcall(restore)
  end

  -- 4) Dual highlight specific test: disable BOTH ts + syntax
  print("⏱  Running: no treesitter + no syntax (motion-only)...")
  pcall(function() vim.treesitter.stop(0) end)
  vim.bo.syntax = "off"
  local no_hl = run_scenario(N, ROUNDS, "− both highlights")
  table.insert(results, no_hl)
  pcall(function() vim.treesitter.start(0) end)
  vim.bo.syntax = "on"

  -- Print results
  print("")
  print("══════════════════════════════════════════════════════════════")
  print("  RESULTS (median of " .. ROUNDS .. " rounds, " .. N .. " moves each)")
  print("──────────────────────────────────────────────────────────────")
  print(("  %-30s %10s %10s %10s"):format("Scenario", "autocmd", "render", "render/mv"))
  print("──────────────────────────────────────────────────────────────")

  for _, r in ipairs(results) do
    local delta = ""
    if r.label ~= baseline.label then
      local pct = ((r.render_median - baseline.render_median) / baseline.render_median) * 100
      if pct < -1 then
        delta = (" ▼%.0f%%"):format(-pct)
      elseif pct > 1 then
        delta = (" ▲%.0f%%"):format(pct)
      end
    end
    print(("  %-30s %8.1f ms %8.1f ms %7.2f ms%s"):format(
      r.label,
      r.autocmd_median,
      r.render_median,
      r.render_per,
      delta
    ))
  end

  print("──────────────────────────────────────────────────────────────")
  print("  autocmd = motion + hooks only (no screen draw)")
  print("  render  = motion + hooks + forced redraw! (full pipeline)")
  print("  ▼ = faster than baseline → disabling this feature helps")
  print("══════════════════════════════════════════════════════════════")

  -- Highlight biggest wins
  print("")
  print("  🏆 Biggest impact (by render time reduction):")
  local sorted = {}
  for _, r in ipairs(results) do
    if r.label ~= baseline.label then
      table.insert(sorted, { label = r.label, delta = baseline.render_median - r.render_median })
    end
  end
  table.sort(sorted, function(a, b) return a.delta > b.delta end)
  for i = 1, math.min(5, #sorted) do
    local s = sorted[i]
    if s.delta > 0 then
      print(("     %d. %s → saved %.1f ms (%.2f ms/move)"):format(i, s.label, s.delta, s.delta / N))
    end
  end
  print("")
end

-- Go
run_all()
