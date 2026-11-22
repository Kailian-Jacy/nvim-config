-- Line comments in the [track] CodeDiff tab: select lines (visual) or stay on a line, `<leader>tq`, type the
-- comment. Each comment is appended to the subcommit's note as {"t":"comment","path","side","line","end_line"}
-- and shown as end-of-line virtual text. Comments are independent of approve/reject; any number per subcommit.
-- Subcommits are immutable (agents only append), so the stored line numbers stay valid.
local M = {}
local NS = vim.api.nvim_create_namespace("agent_track_comments")

local function lifecycle() local ok, lc = pcall(require, "codediff.ui.lifecycle"); return ok and lc or nil end

--- Where is `win` in the current CodeDiff session: { path, side = "new"|"old" } or nil.
--- Inline layout shows the new side in one window (deleted old lines are virtual and not addressable);
--- side-by-side has the old side in original_win and the new side in modified_win.
function M.locate(win)
  local lc = lifecycle(); local s = lc and lc.get_session(vim.api.nvim_win_get_tabpage(win)) or nil
  if not s then return nil end
  if win == s.original_win and s.layout ~= "inline" then
    local p = (s.original_path or "") ~= "" and s.original_path or s.modified_path
    return (p and p ~= "") and { path = p, side = "old" } or nil
  elseif win == s.modified_win then
    local p = (s.modified_path or "") ~= "" and s.modified_path or s.original_path
    return (p and p ~= "") and { path = p, side = "new" } or nil
  end
  return nil
end

--- Selection or cursor line in the current window as a comment anchor.
function M.anchor(range)
  local win = vim.api.nvim_get_current_win(); local loc = M.locate(win)
  if not loc then return nil end
  local l1, l2 = range and range[1] or vim.api.nvim_win_get_cursor(win)[1], range and range[2] or nil
  if l2 and l2 < l1 then l1, l2 = l2, l1 end
  loc.line, loc.end_line = l1, (l2 and l2 ~= l1) and l2 or nil
  return loc
end

--- Render `comments` of the subcommit open in `tab` as virtual text in the diff windows they belong to.
function M.render(tab, comments)
  local lc = lifecycle(); local s = lc and tab and vim.api.nvim_tabpage_is_valid(tab) and lc.get_session(tab) or nil
  if not s then return end
  for _, win in ipairs({ s.original_win, s.modified_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      local buf, loc = vim.api.nvim_win_get_buf(win), M.locate(win)
      pcall(vim.api.nvim_buf_clear_namespace, buf, NS, 0, -1)
      if loc then
        local n = vim.api.nvim_buf_line_count(buf)
        for _, c in ipairs(comments or {}) do
          if c.path == loc.path and (c.side or "new") == loc.side and tonumber(c.line) and c.line >= 1 and c.line <= n then
            local tag = c.end_line and string.format("  💬 L%d-%d: ", c.line, c.end_line) or "  💬 "
            pcall(vim.api.nvim_buf_set_extmark, buf, NS, c.line - 1, 0, { virt_text = { { tag .. (c.body or ""), "AgentTrackComment" } }, virt_text_pos = "eol", hl_mode = "combine" })
          end
        end
      end
    end
  end
end
function M.clear(tab)
  local lc = lifecycle(); local s = lc and tab and vim.api.nvim_tabpage_is_valid(tab) and lc.get_session(tab) or nil
  for _, win in ipairs(s and { s.original_win, s.modified_win } or {}) do
    if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_buf_clear_namespace, vim.api.nvim_win_get_buf(win), NS, 0, -1) end
  end
end
M.ns = NS
return M
