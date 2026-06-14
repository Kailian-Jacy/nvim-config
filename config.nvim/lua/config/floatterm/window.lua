local M = {}

--- Compute geometry for a given slot
---@param slot SlotPosition
---@return table win_config for nvim_open_win
function M.get_geometry(slot)
  local width = vim.o.columns
  local height = vim.o.lines - 1 -- account for cmdline/statusline

  if slot == "centered" then
    local w = math.floor(width * 0.96)
    local h = math.floor(height * 0.92)
    return {
      relative = "editor",
      row = math.floor((height - h) / 2),
      col = math.floor((width - w) / 2),
      width = w,
      height = h,
      border = "rounded",
      style = "minimal",
    }
  elseif slot == "left" then
    local w = math.floor(width * 0.4)
    local h = height - 2
    return {
      relative = "editor",
      row = 0,
      col = 0,
      width = w,
      height = h,
      border = "rounded",
      style = "minimal",
    }
  elseif slot == "right" then
    local w = math.floor(width * 0.4)
    local h = height - 2
    return {
      relative = "editor",
      row = 0,
      col = width - w - 2, -- account for border
      width = w,
      height = h,
      border = "rounded",
      style = "minimal",
    }
  end

  -- fallback to centered
  return M.get_geometry("centered")
end

--- Open a floating window for a buffer at the given slot
---@param bufnr integer
---@param slot SlotPosition
---@return integer winid
function M.open(bufnr, slot)
  local config = M.get_geometry(slot)
  config.focusable = true
  local winid = vim.api.nvim_open_win(bufnr, true, config)
  -- Window options
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].winfixbuf = true
  return winid
end

--- Reposition an existing window to a new slot
---@param winid integer
---@param slot SlotPosition
function M.reposition(winid, slot)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local config = M.get_geometry(slot)
  vim.api.nvim_win_set_config(winid, config)
end

return M
