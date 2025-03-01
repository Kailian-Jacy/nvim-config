local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)

require("config.options")
require("config.lazy")
require("config.autocmds")
require("config.keymaps")

-- Sometimes we want to have different settings across nvim deployments.
-- Load the local config to set something locally.
local _, _ = pcall(require, "config.local")
