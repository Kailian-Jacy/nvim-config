---@alias SlotPosition "centered" | "left" | "right"

---@class TerminalInstance
---@field bufnr integer|nil
---@field jobid integer|nil
---@field tmux_session string|nil
---@field slot SlotPosition
---@field winid integer|nil
---@field winids table<integer, integer>|nil  -- tabpage → winid (global only)
---@field visible boolean

---@class FloatTermState
local State = {
  ---@type TerminalInstance
  global = {
    bufnr = nil,
    jobid = nil,
    tmux_session = nil,
    slot = "centered",
    winid = nil,
    winids = {},  -- tabpage → winid for cross-tab support
    visible = false,
  },
  ---@type table<integer, TerminalInstance>
  locals = {},
  --- Guard flag: when true, WinClosed should not update visible state
  --- (used during reposition to distinguish programmatic close from user close)
  _repositioning = false,
}

--- Get or create local terminal instance for current tab
---@return TerminalInstance
function State:get_local()
  local tab = vim.api.nvim_get_current_tabpage()
  if not self.locals[tab] then
    self.locals[tab] = {
      bufnr = nil,
      jobid = nil,
      tmux_session = nil,
      slot = "centered",
      winid = nil,
      visible = false,
    }
  end
  return self.locals[tab]
end

--- Get who occupies a slot in the current tab
---@param slot SlotPosition
---@return "global"|"local"|nil
function State:slot_occupant(slot)
  if self.global.visible and self.global.slot == slot then
    -- Check if global's winid is in the current tabpage via winids table
    local tab = vim.api.nvim_get_current_tabpage()
    if self.global.winids then
      local wid = self.global.winids[tab]
      if wid and vim.api.nvim_win_is_valid(wid) then
        return "global"
      end
    end
    -- Legacy fallback
    if self.global.winid and vim.api.nvim_win_is_valid(self.global.winid) then
      local win_tab = vim.api.nvim_win_get_tabpage(self.global.winid)
      if win_tab == tab then
        return "global"
      end
    end
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local loc = self.locals[tab]
  if loc and loc.visible and loc.slot == slot then
    if loc.winid and vim.api.nvim_win_is_valid(loc.winid) then
      return "local"
    end
  end
  return nil
end

--- Clean up a tab's local state
---@param tab integer
function State:cleanup_tab(tab)
  self.locals[tab] = nil
end

--- Reset state (for testing)
function State:reset()
  self.global = {
    bufnr = nil,
    jobid = nil,
    tmux_session = nil,
    slot = "centered",
    winid = nil,
    winids = {},
    visible = false,
  }
  self.locals = {}
end

return State
