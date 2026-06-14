local M = {}

--- Compute geometry for a given slot
--- "centered" → fullscreen float (no border)
--- "left"/"right" → split window (not float)
---@param slot SlotPosition
---@return table win_config for nvim_open_win
function M.get_geometry(slot)
  local width = vim.o.columns
  -- vim.o.lines = total terminal height (tabline + editor + statusline + cmdline)
  -- relative="editor" starts below tabline, so available height is:
  --   vim.o.lines - tabline - cmdheight
  -- This covers the entire editor area including statusline, leaving no blank lines.
  local cmdheight = vim.o.cmdheight or 1
  local tabline_height = (vim.o.showtabline == 0) and 0 or 1

  if slot == "centered" then
    -- Fullscreen float, no border — cover entire editor area
    return {
      relative = "editor",
      row = 0,
      col = 0,
      width = width,
      height = vim.o.lines - tabline_height - cmdheight,
      border = "none",
      style = "minimal",
    }
  elseif slot == "left" then
    -- Split window on the left
    local portion = vim.g.terminal_width_left or 0.3
    return {
      split = "left",
      width = math.floor(width * portion),
    }
  elseif slot == "right" then
    -- Split window on the right
    local portion = vim.g.terminal_width_right or 0.3
    return {
      split = "right",
      width = math.floor(width * portion),
    }
  end

  -- fallback to centered
  return M.get_geometry("centered")
end

--- Check if a slot uses floating window (vs split)
---@param slot SlotPosition
---@return boolean
function M.is_float_slot(slot)
  return slot == "centered"
end

--- Open a window for a buffer at the given slot
---@param bufnr integer
---@param slot SlotPosition
---@return integer winid
function M.open(bufnr, slot)
  local config = M.get_geometry(slot)

  if M.is_float_slot(slot) then
    -- Float window
    config.focusable = true
    local winid = vim.api.nvim_open_win(bufnr, true, config)
    -- Window options
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
    vim.wo[winid].winfixbuf = true
    return winid
  else
    -- Split window (Neovim 0.10+ supports split param in nvim_open_win)
    local winid = vim.api.nvim_open_win(bufnr, true, config)
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
    vim.wo[winid].winfixbuf = true
    return winid
  end
end

--- Reposition an existing window to a new slot
--- Since moving between float ↔ split requires closing and recreating,
--- this function returns (new_winid, needs_recreate).
--- If the window can be repositioned in-place (float→float), does so and returns same winid.
--- Otherwise returns nil to signal the caller must recreate.
---@param winid integer
---@param bufnr integer
---@param old_slot SlotPosition
---@param new_slot SlotPosition
---@return integer|nil new_winid  -- nil means caller should use open() after closing old
function M.reposition(winid, bufnr, old_slot, new_slot)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return nil
  end

  local old_is_float = M.is_float_slot(old_slot)
  local new_is_float = M.is_float_slot(new_slot)

  if old_is_float and new_is_float then
    -- Both float: just reconfigure
    local config = M.get_geometry(new_slot)
    vim.api.nvim_win_set_config(winid, config)
    return winid
  end

  -- Mixed (float→split or split→float or split→split): close and recreate
  vim.api.nvim_win_close(winid, true)
  return M.open(bufnr, new_slot)
end

return M
