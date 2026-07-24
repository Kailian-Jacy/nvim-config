-- agent-merge.resolver — optional built-in 3-way merge resolver using Neovim's
-- native diff mode (vimdiff-mergetool style; no external dependency).
--
-- Layout (new tab):   OURS │ RESULT │ THEIRS
--   * RESULT  = the real buffer, seeded with git-style conflict markers (the
--               unresolved regions). Non-conflicting hunks are already merged.
--               Resolve the markers (]c/[c; <leader>co/<leader>ct to pull a
--               side), then :w -> the engine writes and the tab closes on sync.
--   * OURS    = your pre-merge content (read-only reference).
--   * THEIRS  = the agent's on-disk version (read-only reference).
-- All three are in diff mode with inline (DiffText) highlighting via
-- diffopt=…linematch…, so only the differing words on a line are highlighted.
--
-- Closing the tab (or `q` in a reference pane) ABORTS: the resolution attempt
-- is discarded (buffer + base restored via on_abort) and the conflict stays
-- pending, so nothing is silently written and no markers linger.

local M = {}

-- Known-good diffopt for the resolve session (restored on close).
local SESSION_DIFFOPT = "internal,filler,closeoff,linematch:60,algorithm:histogram"

--- buf -> { tab, scratch = {bufnr...}, prev_diffopt, aug, on_abort }
local sessions = {}

local function make_scratch(name, lines, ft)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines or {})
  vim.bo[b].buftype = "nofile"
  vim.bo[b].bufhidden = "wipe"
  vim.bo[b].swapfile = false
  vim.bo[b].filetype = ft or ""
  vim.bo[b].modifiable = false
  pcall(vim.api.nvim_buf_set_name, b, name)
  return b
end

--- Tear down the resolver UI only (no restore). Clears the session first so the
--- resulting TabClosed sees nothing (no recursion, no spurious abort).
local function teardown(buf)
  local s = sessions[buf]
  if not s then return end
  sessions[buf] = nil
  if s.aug then pcall(vim.api.nvim_del_augroup_by_id, s.aug) end
  if s.tab and vim.api.nvim_tabpage_is_valid(s.tab) then
    pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.tab))
  end
  for _, b in ipairs(s.scratch or {}) do
    if vim.api.nvim_buf_is_valid(b) then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end
  if s.prev_diffopt then vim.o.diffopt = s.prev_diffopt end
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(w, function() pcall(vim.cmd, "diffoff") end)
  end
end

--- Success: the buffer was resolved and written; just remove the UI.
function M.finish(buf)
  teardown(buf)
end

--- Abort: discard the resolution attempt (on_abort restores buffer + base) and
--- remove the UI. Triggered by closing the tab or `q` in a reference pane.
function M.abort(buf)
  local s = sessions[buf]
  if not s then return end
  local on_abort = s.on_abort
  teardown(buf)
  if on_abort then pcall(on_abort, buf) end
end

--- Open (or focus) the 3-way diff resolver for `buf`.
--- @param buf integer
--- @param ctx? { ours: string[], theirs: string[], on_abort: fun(buf) }
function M.open(buf, ctx)
  local s = sessions[buf]
  if s and s.tab and vim.api.nvim_tabpage_is_valid(s.tab) then
    vim.api.nvim_set_current_tabpage(s.tab) -- already open; just focus it
    return
  end

  local ft = vim.bo[buf].filetype
  local tail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  local theirs = ctx and ctx.theirs or {}
  local ours = ctx and ctx.ours

  local prev_diffopt = vim.o.diffopt
  vim.o.diffopt = SESSION_DIFFOPT

  -- RESULT: the real buffer, in a fresh tab.
  vim.cmd("tab sbuffer " .. buf)
  local tab = vim.api.nvim_get_current_tabpage()
  local result_win = vim.api.nvim_get_current_win()
  vim.wo[result_win].winbar = " RESULT (edit & :w)"
  vim.cmd("diffthis")

  local scratch = {}

  -- THEIRS on the right.
  vim.cmd("rightbelow vsplit")
  local theirs_buf = make_scratch("agent://THEIRS/" .. tail, theirs, ft)
  vim.api.nvim_win_set_buf(0, theirs_buf)
  vim.wo[0].winbar = " THEIRS (agent)"
  vim.cmd("diffthis")
  scratch[#scratch + 1] = theirs_buf

  -- OURS on the left (only if we have it; lost on a bare reopen).
  local ours_buf
  if ours then
    vim.api.nvim_set_current_win(result_win)
    vim.cmd("leftabove vsplit")
    ours_buf = make_scratch("agent://OURS/" .. tail, ours, ft)
    vim.api.nvim_win_set_buf(0, ours_buf)
    vim.wo[0].winbar = " OURS (yours)"
    vim.cmd("diffthis")
    scratch[#scratch + 1] = ours_buf
  end

  vim.api.nvim_set_current_win(result_win)

  -- Convenience keymaps (buffer-local to RESULT).
  if ours_buf then
    vim.keymap.set("n", "<leader>co", function() vim.cmd("diffget " .. ours_buf) end,
      { buffer = buf, desc = "agent-merge: take OURS hunk" })
  end
  vim.keymap.set("n", "<leader>ct", function() vim.cmd("diffget " .. theirs_buf) end,
    { buffer = buf, desc = "agent-merge: take THEIRS hunk" })
  for _, b in ipairs(scratch) do
    vim.keymap.set("n", "q", function() M.abort(buf) end,
      { buffer = b, desc = "agent-merge: abort resolver" })
  end

  -- Closing the tab manually = abort (restore + tear down).
  local aug = vim.api.nvim_create_augroup("AgentMergeResolve" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = aug,
    callback = function()
      local cur = sessions[buf]
      if cur and (not cur.tab or not vim.api.nvim_tabpage_is_valid(cur.tab)) then
        M.abort(buf)
      end
    end,
  })

  sessions[buf] = {
    tab = tab, scratch = scratch, prev_diffopt = prev_diffopt, aug = aug,
    on_abort = ctx and ctx.on_abort,
  }
end

return M
