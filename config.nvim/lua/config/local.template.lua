-- This is a lua file that contains local settings.
-- It will not be synchronized between git repos.
-- Rename this file to local.lua to make it take effect.

M = {}

local modules = {}

M.before_all = function()
  -- Status bar sign.
  -- vim.g._status_bar_system_icon = "?"

  -- -- Set `vim.g.modules` customization with `modules`
  -- modules.svn = false
  -- -- Be sure to write them back
  -- vim.g.modules = modules

  -- Tab name indicator. Name will be marked if any matching.
  -- The former, the priorer.
  -- vim.g.tab_path_mark = { ["Branch_OB_Publish"] = "P", ["Branch_GServers_%d+"] = "G", ["Branch_NServers_%d+"] = "N" }
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
