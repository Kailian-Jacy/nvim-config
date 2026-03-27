-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Load helper functions and resource detection first
require("config.helpers")

-- Load tabline implementation
require("config.tabline")

-- Helper functions and resource detection.
local _if_not_set_or_true = function(var)
  return var == nil or var == true
end

-- Modules enabling setup. Modules variables could be overriden by local.lua
---@type table<ModuleConfig>
local default_modules_config = {
  rust = {
    enabled = vim.fn.executable("rustc") == 1,
  },
  go = {
    enabled = vim.fn.executable("go") == 1,
  },
  python = {
    enabled = vim.fn.executable("python") == 1 or vim.fn.executable("python3") == 1,
  },
  cpp = {
    enabled = vim.fn.executable("gcc") == 1,
  },
  copilot = {
    enabled = vim.fn.executable("node") == 1,
  },
  bookmarks = {
    enabled = vim.g._resource_executable_sqlite,
  },
  svn = {
    enabled = vim.fn.executable("svn") == 1,
  },
}

vim.g.modules = vim.tbl_deep_extend("keep", (vim.g.modules or {}), default_modules_config)

--------------------------------------------------
-- Optional Features
--------------------------------------------------

-- If reading binary with xxd and show as human-readable text.
vim.g.read_binary_with_xxd = false

-- Terminal
vim.g.terminal_width_right = 0.3
vim.g.terminal_width_left = 0.3
vim.g.terminal_width_bottom = 0.3
vim.g.terminal_width_top = 0.3
vim.g.terminal_auto_insert = true
vim.g.terminal_default_tmux_session_name = "nvim-attached"

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- UI related.
vim.cmd([[ set laststatus=3 ]])     -- Global lualine across each windows.
vim.cmd([[ set signcolumn=yes:1 ]]) -- Constant status column indentation.
-- cmdheight=0 works well with noice.nvim which provides a floating cmdline.
-- noshowmode/noruler/noshowcmd reduce UI clutter since noice handles messages.
vim.cmd([[ set cmdheight=0 noshowmode noruler noshowcmd ]])

-- Highlighting Source.
vim.cmd([[ syntax off ]])                       -- we won't need syntax anytime. Use treesitter at least.
vim.g.use_treesitter_highlight = { "c", "cpp" }

-- Undo history even when the file is closed.
vim.opt.undofile = true

-- Relative number and cursorline.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Copilot
vim.g.copilot_filetypes = {
  markdown = false,
  yaml = false,
  toml = false,
}

vim.opt.fillchars = "diff:╱,eob:~,fold: ,foldclose:,foldopen:,foldsep: "
vim.g.debugging_status = "NoDebug"
vim.g.recording_status = false
vim.g.debugging_keymap = false

-- virtual text truncate size.
vim.g.debug_virtual_text_truncate_size = 20

-- Auto read configuration files.
vim.o.autoread = true

-- neovide settings.
vim.g.neovide_show_border = true
vim.g.neovide_input_macos_option_key_is_meta = 'only_left'
vim.g.neovide_scroll_animation_length = 0.13
vim.g.neovide_position_animation_length = 0.08
vim.g.neovide_cursor_animate_command_line = true
vim.g.neovide_cursor_trail_size = 0.1

-- appearance
local alpha = function(transparency)
  return string.format("%x", math.floor(255 * transparency))
end
vim.g.neovide_opacity = 0.99
vim.g.neovide_normal_opacity = 0.3

-- Last location
vim.g.LAST_WORKING_DIRECTORY = "~"

-- Background color transparency.
vim.g.neovide_background_color = "#13103d" .. alpha(vim.g.transparency or 0.86)

-- padding surrounding.
vim.g.neovide_padding_top = 10
vim.g.neovide_padding_right = 10
vim.g.neovide_padding_bottom = 10

-- Blur
vim.g.neovide_window_blurred = true
vim.g.neovide_floating_blur_amount_x = 5
vim.g.neovide_floating_blur_amount_y = 5
vim.g.neovide_input_use_logo = 1

-- Global tabstop.
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 0
vim.opt.expandtab = true

-- [ These are the Options needs to be set when migration to new machine. ]

-- Some would load env from someplace out of bash or zshrc.
vim.g.dotenv_dir = vim.fn.expand("$HOME/")

-- obsidian related settings.
vim.g.obsidian_executable = "/Applications/Obsidian.app"
vim.g.obsidian_functions_enabled = require("config.helpers").obsidian_app_exists()
vim.g.obsidian_vault = "/Users/kailianjacy/Library/Mobile Documents/iCloud~md~obsidian/Documents/universe"

-- yanky ring reserve least content length.
vim.g.yanky_ring_accept_length = 10
vim.g.yanky_ring_max_accept_length = 1000

-- Snippet path settings
vim.g.import_user_snippets = true
vim.g.user_vscode_snippets_path = {
  vim.fn.stdpath("config") .. "/snip/",
}
if vim.g._env_os_type == "MACOS" then
  vim.g.user_vscode_snippets_path[#vim.g.user_vscode_snippets_path + 1] =
      vim.fn.expand("$HOME/Library/Application Support/Code/User/snippets/")
end

-- Add any additional options here
vim.g.autoformat = false

-- Format behavior settings for different filetypes.
---@type table<string, "all" | "restrict" | "select_only">
vim.g.format_behavior = {
  default = "restrict",
  rust = "all"
}
vim.g.max_silent_format_line_cnt = 10

-- Theme setting
vim.g.scroll_bar_hide = true
vim.g.indent_blankline_hide = true
