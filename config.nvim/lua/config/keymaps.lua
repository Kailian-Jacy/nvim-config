-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("v", "/", '"fy/\\V<C-R>f<CR>')
--vim.keymap.set("n", "<leader>s", "<cmd>w<CR>") -- deprecated. Now use auto save.
vim.keymap.set("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })

vim.keymap.del("n", "<leader>l")
vim.keymap.del("n", "<leader>L")
