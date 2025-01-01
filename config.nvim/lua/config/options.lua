-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

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

vim.opt.fillchars = "diff:╱,eob:~,fold: ,foldclose:,foldopen:,foldsep: "
--[[Running = "Running",
  Stopped = "Stopped",
  DebugOthers = "DebugOthers",
  NoDebug = "NoDebug"]]
vim.g.debugging_status = "NoDebug"

-- neovide settings. Always ready to be connected from remote neovide.
-- disable too much animation
vim.g.neovide_scroll_animation_length = 0
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_cursor_trail_size = 0
-- appearance
-- vim.print(string.format("%x", math.floor(255 * 0))) -- 0.88 e0; 0.9 cc; 0 0
local alpha = function()
  return string.format("%x", math.floor(255 * (vim.g.transparency or 0.8)))
end
vim.g.neovide_transparency = 0.3 -- 0: fully transparent.
vim.g.transparency = 0.9 -- 0: fully transparent.
vim.g.neovide_padding_top = 10
-- vim.g.neovide_background_color = "#13103de0"
vim.g.neovide_background_color = "#13103d" .. alpha()

-- Not to bother around blurring. Neovide is just setting blur to a fixed value.
--  Unconfortable.
vim.g.neovide_window_blurred = false
-- vim.g.neovide_window_floating_blur = 0.1
-- vim.g.neovide_floating_blur_amount_x = 0
-- vim.g.neovide_floating_blur_amount_y = 0
-- vim.g.neovide_window_floating_opacity = 0.1
-- vim.g.neovide_floating_blur = 0.1
-- vim.g.neovide_floating_blur_amount = 0.1

-- TODO: Not working.
vim.g.neovide_text_gamma = 0.0
vim.g.neovide_text_contrast = 0.5
-- floating window shadow
vim.g.neovide_floating_shadow = true
vim.g.neovide_floating_z_height = 10
vim.g.neovide_light_angle_degrees = 45
vim.g.neovide_light_radius = 5
vim.g.neovide_show_border = true
-- TODO: Not working.
vim.g.neovide_hide_mouse_when_typing = false
vim.g.neovide_confirm_quit = true
-- refresh rate and cidling
vim.g.neovide_refresh_rate = 100 -- frame rate.
vim.g.neovide_refresh_rate_idle = 5
vim.g.neovide_no_idle = false
-- Paste to cmd + v
vim.g.neovide_input_use_logo = 1
vim.api.nvim_set_keymap("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<D-v>", '<C-\\><C-o>"+p', { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("c", "<D-v>", "<C-r>+", { noremap = true, silent = true })




-- [ These are the Options needs to be set when migration to new machine. ]

-- Some would load env from someplace out of bash or zshrc. If non specified, just leave nil.
vim.g.dotenv_dir = vim.fn.expand('$HOME/')

-- obsidian related settings.
-- obsidian functionalities could not be enabled on the remote side. So compatibility out of macos is not considerd.
vim.g.obsidian_executable = "/applications/obsidian.app"
vim.g.obsidian_functions_enabled = obsidian_app_exists()
vim.g.obsidian_vault = "/Users/kailianjacy/Library/Mobile Documents/iCloud~md~obsidian/Documents/universe"

-- Snippet path settings
vim.g.import_user_snippets = true
vim.g.user_vscode_snippets_path = "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" -- How to get: https://arc.net/l/quote/fjclcvra

-- Add any additional options here
vim.g.autoformat = false
