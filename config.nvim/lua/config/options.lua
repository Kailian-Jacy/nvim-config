-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.minimap_highlight_search = 1
vim.g.minimap_git_colors = 1
vim.g.autoformat = false
vim.opt.fillchars = "diff:╱,eob:~,fold: ,foldclose:,foldopen:,foldsep: "
--[[Running = "Running",
  Stopped = "Stopped",
  DebugOthers = "DebugOthers",
  NoDebug = "NoDebug"]]
vim.g.debugging_status = "NoDebug"

-- obsidian related settings.
vim.g.obsidian_executable = ""
vim.g.obsidian_functions_enabled = false
vim.g.obsidian_vault = "/Users/kailianjacy/Library/Mobile Documents/iCloud~md~obsidian/Documents/universe"

local function obsidian_app_exists()
  if vim.fn.has("mac") == 1 then
    vim.g.obsidian_executable = "/applications/obsidian.app"
    if vim.fn.isdirectory(vim.g.obsidian_executable) == 1 then
      return true
    end
  end
  return false
end

if obsidian_app_exists() then
  vim.g.obsidian_functions_enabled = true
end

