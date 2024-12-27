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
end




-- [ These are the Options needs to be set when migration to new machine. ]

-- Some would load env from someplace out of bash or zshrc. If non specified, just leave nil.
vim.g.dotenv_dir = vim.fn.expand('$HOME/')

-- obsidian related settings.
-- obsidian functionalities could not be enabled on the remote side. So compatibility out of macos is not considerd.
vim.g.obsidian_functions_enabled = vim.fn.has("mac") == 1 and obsidian_app_exists()
vim.g.obsidian_executable = "/applications/obsidian.app"
vim.g.obsidian_vault = "/Users/kailianjacy/Library/Mobile Documents/iCloud~md~obsidian/Documents/universe"

-- Snippet path settings
vim.g.import_user_snippets = true
vim.g.user_vscode_snippets_path = "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" -- How to get: https://arc.net/l/quote/fjclcvra

-- Add any additional options here
vim.g.autoformat = false
