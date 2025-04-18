-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Optional Features
--------------------------------------------------
-- If reading binary with xxd and show as human-readable text.
--
-- Disabled for now. Generally, reading binary in vim does not make any sense.
-- Loading and converting the binary is very heavy work for vim.
-- I'll leave an option here to allow enabling it when needed.
vim.g.read_binary_with_xxd = false
--------------------------------------------------

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- UI related.
vim.cmd([[ set laststatus=3 ]]) -- Global lualine across each windows.
vim.cmd([[ set signcolumn=yes:1 ]]) -- Constant status column indentation.
vim.cmd([[ set cmdheight=0 noshowmode noruler noshowcmd ]])

-- Undo history even when the file is closed.
vim.opt.undofile = true

-- Relative number and cursorline.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Making neovim comaptible with possible gbk encodings.
-- According to neovim doc, set encoding= option is deprecated.
-- Just list possible encodings in the fileencodings, and neovim will decide.
-- gb2312 can't be placed after latin1. Don't know why. Possibly because detect failure.
-- vim.cmd[[ set fileencodings=ucs-bom,utf-8,gb2312,latin1,euc-cn ]]

-- [[ Helper functions. Just skip them. ]]
local function obsidian_app_exists()
  if vim.fn.has("mac") == 1 then
    if vim.fn.isdirectory(vim.g.obsidian_executable) == 1 then
      return true
    end
    -- as I don't use other os as desktop, the others are not implemented yet.
  end
  return false
end

-- Tabline
-- Set the current tab name as the working directory name.
function MyTabLine()
  local tabline = ""
  for index = 1, vim.fn.tabpagenr("$") do
    -- select the highlighting
    if index == vim.fn.tabpagenr() then
      tabline = tabline .. "%#TabLineSel#"
    else
      tabline = tabline .. "%#TabLine#"
    end

    -- set the tab page number (for mouse clicks)
    tabline = tabline .. "%" .. index .. "T"

    local win_num = vim.fn.tabpagewinnr(index)
    local working_directory = vim.fn.getcwd(win_num, index)
    local project_name = vim.fn.fnamemodify(working_directory, ":t")
    tabline = tabline .. " " .. project_name .. " "
  end

  -- after the last tab fill with TabLineFill and reset tab page nr
  tabline = tabline .. "%#TabLineFill#%T"

  -- -- right-align the label to close the current tab page
  -- if vim.fn.tabpagenr('$') > 1 then
  --     tabline = tabline .. '%=%#TabLine#%999Xclose'
  -- end
  return tabline
end
vim.go.tabline = "%!v:lua.MyTabLine()"

vim.g.function_get_selected_content = function()
  local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return table.concat(vim.fn.getregion(vstart, vend), "\n")
end

vim.opt.fillchars = "diff:╱,eob:~,fold: ,foldclose:,foldopen:,foldsep: "
--[[Running = "Running",
  Stopped = "Stopped",
  DebugOthers = "DebugOthers",
  NoDebug = "NoDebug"]]
vim.g.debugging_status = "NoDebug"
vim.g.recording_status = false

-- neovide settings. Always ready to be connected from remote neovide.
vim.g.neovide_show_border = true

vim.g.neovide_scroll_animation_length = 0.13
vim.g.neovide_position_animation_length = 0.08
vim.g.neovide_cursor_animate_command_line = true
-- disable too much animation
vim.g.neovide_cursor_trail_size = 0.1

-- appearance
-- vim.print(string.format("%x", math.floor(255 * 0))) -- 0.88 e0; 0.9 cc; 0 0
local alpha = function()
  return string.format("%x", math.floor(255 * (vim.g.transparency or 0.8)))
end
-- Visual parts transparency.
-- vim.g.neovide_transparency = 1 -- 0: fully transparent.
vim.g.neovide_opacity = 1 -- 0: fully transparent. # neovide 0.15: upgraded from neovide_transparency.
-- Normal Background transparency.
vim.g.neovide_normal_opacity = 0.3

-- Last location
vim.g.LAST_WORKING_DIRECTORY = "~"

-- Background color transparency. 0 fully transparent.
-- FIXME: Setting this option to none-zero makes border disappear.
vim.g.transparency = 0.86
-- FIXME: It reports this option is currently suppressed. But not using this feature disables floating window transparency.
vim.g.neovide_background_color = "#13103d" .. alpha()

-- padding surrounding.
vim.g.neovide_padding_top = 10
vim.g.neovide_padding_right = 10 -- floating point right side padding.
vim.g.neovide_padding_bottom = 10

-- Unconfigurable blurr amount.
-- Not to bother around blurring. Neovide is just setting blur to a fixed value.
vim.g.neovide_window_blurred = false

-- Setting floating blur amount.
vim.g.neovide_floating_blur_amount_x = 5
vim.g.neovide_floating_blur_amount_y = 5

-- Global tabstop.
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 0
vim.opt.expandtab = true

-- Paste to cmd + v
vim.g.neovide_input_use_logo = 1
-- vim.api.nvim_set_keymap("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<D-v>", '<C-\\><C-o>"+p', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("c", "<D-v>", "<C-r>+", { noremap = true, silent = true })

-- copilot endpoint
vim.g.copilot_auth_provider_url = "https://copilot.aizahuo.com"

-- [ These are the Options needs to be set when migration to new machine. ]

-- Some would load env from someplace out of bash or zshrc. If non specified, just leave nil.
vim.g.dotenv_dir = vim.fn.expand("$HOME/")

-- obsidian related settings.
-- obsidian functionalities could not be enabled on the remote side. So compatibility out of macos is not considerd.
vim.g.obsidian_executable = "/applications/obsidian.app"
vim.g.obsidian_functions_enabled = obsidian_app_exists()
vim.g.obsidian_vault = "/Users/kailianjacy/Library/Mobile Documents/iCloud~md~obsidian/Documents/universe"

-- yanky ring reserve least content length.
vim.g.yanky_ring_accept_length = 10

-- Snippet path settings
vim.g.import_user_snippets = true
vim.g.user_vscode_snippets_path = {
  vim.fn.stdpath("config") .. "/snip/", -- How to get: https://arc.net/l/quote/fjclcvra
  vim.fn.expand('$HOME/Library/Application Support/Code/User/snippets/'), -- Default Vscode snippet path under MacOS.
}

-- vim.g.user_vscode_snippets_path = "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" -- How to get: https://arc.net/l/quote/fjclcvra
-- Linking: ln -s "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" /Users/kailianjacy/.config/nvim/snip.

-- Add any additional options here
vim.g.autoformat = false

-- Theme setting
-- vim.opt.statuscolumn = "%=%{v:relnum?v:relnum:v:lnum} %s"
