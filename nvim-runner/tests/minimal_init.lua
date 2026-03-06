-- Minimal init for testing nvim-runner
-- Usage: nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_runner_spec.lua" -c "qa!"

-- Add plugin to runtimepath
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_dir)

-- Minimal settings
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

-- Setup with defaults
require("nvim-runner").setup()
