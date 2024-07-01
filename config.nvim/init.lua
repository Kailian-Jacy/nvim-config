-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)
