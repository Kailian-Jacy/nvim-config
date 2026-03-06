-- nvim-runner/lua/nvim-runner/util.lua
-- Utility functions (decoupled from vim.g.*)

local M = {}

--- Check if currently in visual mode
---@return boolean
function M.is_in_visual_mode()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

--- Get selected content in visual mode
---@return string
function M.get_selected_content()
  local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return table.concat(vim.fn.getregion(vstart, vend), "\n")
end

return M
