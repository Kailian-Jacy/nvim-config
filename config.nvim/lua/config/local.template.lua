-- This is a lua file that contains local settings.
-- It will not be synchronized between git repos.
-- Rename this file to local.lua to make it take effect.

M = {}

M.before_all = function()
  -- Status bar sign.
  -- vim.g._status_bar_system_icon = "?"
end
M.after_options = function()
  -- Temporary workaround for tencent gbk encodings.
  -- vim.g.clipboard = nil
  -- vim.g.do_not_format_all = true
  -- vim.cmd[[ set fileencodings=ucs-bom,gb2312,utf-8,latin1,euc-cn ]]
end

M.before_plugins_load = function() end
M.after_plugins_load = function() end

M.before_autocmds = function() end
M.after_autocmds = function() end

M.before_keymaps = function() end
M.after_all = function() end

return M
