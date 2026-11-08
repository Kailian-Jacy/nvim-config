-- agent-merge.resolver — built-in 3-way merge resolver using Neovim's native
-- diff mode (vimdiff-mergetool style; no external dependency).
--
-- Layout (new tab):   OURS │ RESULT │ THEIRS
--   * RESULT  = the real buffer, seeded with git-style conflict markers (the
--               unresolved regions). Non-conflicting hunks are already merged.
--               Resolve the markers (]c/[c; <leader>co/<leader>ct to pull a
--               side), then SAVE (:w / <leader><CR>) = "the resolution is done".
--   * OURS    = your pre-merge content (read-only reference).
--   * THEIRS  = the agent's on-disk version (read-only reference).
-- All three are in diff mode with inline (DiffText) highlighting via
-- diffopt=…linematch…, so only the differing words on a line are highlighted.
--
-- CLOSING any of the three windows (:q, <C-w>c, :tabclose, `q` in a reference
-- pane) ABORTS: the attempt is discarded (on_abort restores the buffer) and the
-- conflict stays pending, so nothing is silently written.

local M = {}

-- Known-good diffopt for the resolve session (restored on close).
local SESSION_DIFFOPT = "internal,filler,closeoff,linematch:60,algorithm:histogram"

--- buf -> { tab, wins, scratch = {bufnr...}, prev_diffopt, aug, on_abort }
local sessions = {}
--- buf -> diffopt to restore once a detached session's deferred teardown runs
local restore_diffopt = {}

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

--- End the session immediately (so no further close counts as an abort), and
--- tear the UI down on the next tick: we may be inside WinClosed, or inside the
--- BufWriteCmd of `:wq`, where closing windows now would be unsafe.
local function detach(buf)
  local s = sessions[buf]
  if not s then return nil end
  sessions[buf] = nil
  if s.aug then pcall(vim.api.nvim_del_augroup_by_id, s.aug) end
  for _, lhs in ipairs({ "<leader>co", "<leader>ct" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = buf })
  end
  restore_diffopt[buf] = s.prev_diffopt
  vim.schedule(function()
    if s.tab and vim.api.nvim_tabpage_is_valid(s.tab) and #vim.api.nvim_list_tabpages() > 1 then
      pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.tab))
    end
    for _, b in ipairs(s.scratch or {}) do
      if vim.api.nvim_buf_is_valid(b) then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
    -- A new session may have been opened for the same buffer meanwhile (the
    -- commit re-entered the flow): it owns diff mode and diffopt now.
    if sessions[buf] then return end
    if restore_diffopt[buf] then vim.o.diffopt = restore_diffopt[buf] end
    restore_diffopt[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
      for _, w in ipairs(vim.fn.win_findbuf(buf)) do
        vim.api.nvim_win_call(w, function() pcall(vim.cmd, "diffoff") end)
      end
    end
  end)
  return s
end

--- @return boolean  a resolve session is open for `buf`
function M.active(buf)
  return sessions[buf] ~= nil
end

--- Success: the resolution was committed; just remove the UI.
function M.finish(buf)
  detach(buf)
end

--- Abort: discard the resolution attempt (on_abort restores the buffer) and
--- remove the UI.
function M.abort(buf)
  local s = detach(buf)
  if s and s.on_abort then pcall(s.on_abort, buf) end
end

--- Open (or focus) the 3-way diff resolver for `buf`.
--- @param buf integer
--- @param ctx { ours: string[], theirs: string[], on_abort?: fun(buf) }
function M.open(buf, ctx)
  local s = sessions[buf]
  if s and s.tab and vim.api.nvim_tabpage_is_valid(s.tab) then
    vim.api.nvim_set_current_tabpage(s.tab) -- already open; just focus it
    return
  end

  local ft = vim.bo[buf].filetype
  local tail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

  local prev_diffopt = restore_diffopt[buf] or vim.o.diffopt
  restore_diffopt[buf] = nil
  vim.o.diffopt = SESSION_DIFFOPT

  -- RESULT: the real buffer, in a fresh tab.
  vim.cmd("tab sbuffer " .. buf)
  local tab = vim.api.nvim_get_current_tabpage()
  local result_win = vim.api.nvim_get_current_win()
  vim.wo[result_win].winbar = " RESULT (resolve, then save)"
  vim.cmd("diffthis")
  local wins = { result_win }
  local scratch = {}

  -- THEIRS on the right.
  vim.cmd("rightbelow vsplit")
  local theirs_buf = make_scratch("agent://THEIRS/" .. tail, ctx.theirs, ft)
  vim.api.nvim_win_set_buf(0, theirs_buf)
  vim.wo[0].winbar = " THEIRS (agent)"
  vim.cmd("diffthis")
  scratch[#scratch + 1], wins[#wins + 1] = theirs_buf, vim.api.nvim_get_current_win()

  -- OURS on the left.
  vim.api.nvim_set_current_win(result_win)
  vim.cmd("leftabove vsplit")
  local ours_buf = make_scratch("agent://OURS/" .. tail, ctx.ours, ft)
  vim.api.nvim_win_set_buf(0, ours_buf)
  vim.wo[0].winbar = " OURS (yours)"
  vim.cmd("diffthis")
  scratch[#scratch + 1], wins[#wins + 1] = ours_buf, vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(result_win)

  -- Convenience keymaps (buffer-local to RESULT).
  vim.keymap.set("n", "<leader>co", function() vim.cmd("diffget " .. ours_buf) end,
    { buffer = buf, desc = "agent-merge: take OURS hunk" })
  vim.keymap.set("n", "<leader>ct", function() vim.cmd("diffget " .. theirs_buf) end,
    { buffer = buf, desc = "agent-merge: take THEIRS hunk" })
  for _, b in ipairs(scratch) do
    vim.keymap.set("n", "q", function() M.abort(buf) end,
      { buffer = b, desc = "agent-merge: abort resolver" })
  end

  -- Closing any resolver window (or the whole tab) = abort.
  local aug = vim.api.nvim_create_augroup("AgentMergeResolve" .. buf, { clear = true })
  for _, w in ipairs(wins) do
    vim.api.nvim_create_autocmd("WinClosed", {
      group = aug,
      pattern = tostring(w),
      callback = function() M.abort(buf) end,
    })
  end

  sessions[buf] = {
    tab = tab, wins = wins, scratch = scratch, prev_diffopt = prev_diffopt, aug = aug,
    on_abort = ctx.on_abort,
  }
end

return M
