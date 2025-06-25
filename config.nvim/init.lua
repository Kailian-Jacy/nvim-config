-- Sometimes we want to have different settings across nvim deployments.
-- Load the local config to set something locally.
local success, local_funcs = pcall(require, "config.local")

if success and local_funcs.before_all and type(local_funcs.before_all) == "function" then
  local_funcs.before_all()
end

local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)

-- load options.
require("config.options")
if success and local_funcs.after_options and type(local_funcs.after_options) == "function" then
  local_funcs.after_options()
end

-- load plugins.
if success and local_funcs.before_plugins_load and type(local_funcs.before_plugins_load) == "function" then
  local_funcs.before_plugins_load()
end
require("config.lazy")
if success and local_funcs.after_plugins_load and type(local_funcs.after_plugins_load) == "function" then
  local_funcs.after_plugins_load()
end

-- Load autocmds
if success and local_funcs.before_autocmds and type(local_funcs.before_autocmds) == "function" then
  local_funcs.before_autocmds()
end
require("config.autocmds")
if success and local_funcs.after_autocmds and type(local_funcs.after_autocmds) == "function" then
  local_funcs.after_autocmds()
end

-- Load keymaps.
if success and local_funcs.before_keymaps and type(local_funcs.before_keymaps) == "function" then
  local_funcs.before_keymaps()
end
require("config.keymaps")
if success and local_funcs.after_all and type(local_funcs.after_all) == "function" then
  local_funcs.after_all()
end
