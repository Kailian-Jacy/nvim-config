-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Sometimes we want to have different settings across nvim deployments.
local nvim_conf_dir = (...):match("(.-)[^%.]+$")
-- Load the local config to set something locally.
local _, _ = pcall(require, nvim_conf_dir .. "local") -- handle the local module with error tolerance.

-- VimEnter does not work here.
-- vim.api.nvim_create_autocmd("VimEnter", {
--   callback = function()
--     vim.fn.writefile({ "111" }, "/Users/kailianjacy/test.txt")
--   end,
-- })
-- To do something similar, just do it here.
--
-- Start a tmux session in the background if none.
-- TODO: Not sure if working.
vim.schedule(function()
  vim.fn.system("tmux", { "new", "-As0" })
end)

-- Surroudings workaround
require("visual-surround").setup({
  surround_chars = { "{", "}", "[", "]", "(", ")", "'", '"', "`" },
})

for _, key in ipairs({ "<", ">" }) do
  vim.keymap.set("x", key, function()
    local mode = vim.api.nvim_get_mode().mode
    -- do not change the default behavior of '<' and '>' in visual-line mode
    if mode == "V" then
      return key .. "gv"
    else
      vim.schedule(function()
        require("visual-surround").surround(key)
      end)
      return "<ignore>"
    end
  end, {
    desc = "[visual-surround] Surround selection with " .. key .. " (visual mode and visual block mode)",
    expr = true,
  })
end

-- Set cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:ver25"
vim.api.nvim_create_autocmd({
  "TermOpen",
  "WinEnter",
}, {
  pattern = "term://*",
  command = "startinsert",
})

-- multiple instances of neovide.
vim.api.nvim_create_user_command("NeovideNew", function()
  vim.cmd([[ ! open -n "/Applications/Neovide.app" --args --grid 80x25 ]])
end, {})

-- current file path into clipboard.
vim.api.nvim_create_user_command("CopyFilePath", function(opt)
  if #opt.args == 0 then
    opt = "full"
  else
    opt = opt.args
  end
  if opt == "full" then
    local full_path = vim.fn.expand("%:p")
    vim.fn.setreg("*", full_path)
  elseif opt == "relative" then
    local relative_path = vim.fn.expand("%:p"):gsub(vim.fn.getcwd() .. "/", "")
    vim.fn.setreg("*", relative_path)
  elseif opt == "dir" then
    local workdir = vim.fn.getcwd()
    vim.fn.setreg("*", workdir)
  elseif opt == "filename" then
    local filename = vim.fn.expand("%:t")
    vim.fn.setreg("*", filename)
  else
    vim.notify("Invalid option: " .. opt, vim.log.levels.ERROR)
  end
end, { nargs = "?" })

-- Macro recording related.
vim.api.nvim_create_autocmd("RecordingEnter", {
  callback = function()
    vim.g.recording_status = true
    require("lualine").refresh()
    vim.print_silent("Macro recording.")
  end,
})

vim.api.nvim_create_autocmd("RecordingLeave", {
  callback = function()
    vim.g.recording_status = false
    require("lualine").refresh()
    vim.print_silent("End recording.")
  end,
})

-- Start at the last place exited.
-- Seems like "VimEnter" function not working in autocmds.lua.
vim.cmd("cd " .. (vim.g.LAST_WORKING_DIRECTORY or ""))
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.g.LAST_WORKING_DIRECTORY = vim.fn.getcwd()
  end,
})

-- keymap for markdown ft
local function is_obs_md(buf)
  if vim.bo[buf].filetype == "markdown" and vim.startswith(vim.fn.expand("%:p"), vim.g.obsidian_vault) then
    return true
  end
  return false
end

vim.api.nvim_create_autocmd("BufRead", {
  group = vim.api.nvim_create_augroup("markdown", { clear = true }),
  callback = function(opts)
    if is_obs_md(opts.buf) then
      -- Commands
      vim.keymap.set({ "n", "v" }, "<leader>fd", "<cmd>ObsidianBridgeTelescopeCommand<CR>", { buffer = true })
      -- follow link
      vim.keymap.set({ "n", "v" }, "gf", function()
        if require("obsidian").util.cursor_on_markdown_link() then
          return "<cmd>ObsidianFollowLink<CR>"
        else
          return "gf"
        end
      end, { buffer = true })
      -- Image Paste in Vault image base.
      vim.keymap.set(
        { "n", "v" },
        "<leader>pi",
        "<cmd>ObsidianPasteImg " .. os.date("%Y%m%d%H%M%S") .. "<cr>",
        { buffer = true }
      )
    else
      if vim.bo[opts.buf].filetype == "markdown" then
        vim.keymap.set({ "n", "v" }, "<leader>pi", "<cmd>PasteImage<cr>", { buffer = true })
      end
    end
  end,
})

-- Navigatin Z wrapper
-- before cd there, add to zoxide.
vim.api.nvim_create_user_command("Cd", function(opts)
  opts = opts or ""
  vim.cmd('silent !zoxide add "' .. opts.args .. '"')
  vim.cmd("cd " .. opts.args)
  vim.cmd("pwd")
end, { nargs = "?" })

vim.api.nvim_create_user_command("TelescopeAutoCommands", function(opts)
  require("telescope.builtin").autocommands(opts)
end, { desc = "Telescope picker for all auto commands and events" })

-- Trigger linter
local function lint()
  -- try_lint without arguments runs the linters defined in `linters_by_ft`
  -- for the current filetype
  require("lint").try_lint()
  -- You can call `try_lint` with a linter name or a list of names to always
  -- run specific linters, independent of the `linters_by_ft` configuration
  -- require("lint").try_lint("cspell")
end
vim.api.nvim_create_user_command("Lint", lint, {})
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = lint,
})
-- Disabled auto lint when opening files. They are annoying when reading source codes.
-- Normally we want linting to be done when formatting triggered
-- If really need, just call Lint command mannually.
--[[vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  callback = lint,
})]]

-- Workaround for a tmux problem:
--[[vim.api.nvim_create_autocmd("VimLeave", {
  command = "set guicursor=a:ver1",
})]]
-- dap close float window on esc
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dap-float",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "<esc>", "<cmd>close!<CR>", { noremap = true, silent = true })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dap-float",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close!<CR>", { noremap = true, silent = true })
  end,
})

-- Show linters being used
vim.api.nvim_create_user_command("LintInfo", function()
  local filetype = vim.bo.filetype
  local linters = require("lint").linters_by_ft[filetype]

  if linters then
    print("Linters for " .. filetype .. ": " .. table.concat(linters, ", "))
  else
    print("No linters configured for filetype: " .. filetype)
  end
end, {})

-- Custom Simple Commands.
-- LuaCommand scripts.
vim.api.nvim_create_user_command("Lcmd", function()
  vim.cmd("new")
  vim.cmd("setfiletype lua")
end, {})
vim.api.nvim_create_user_command("Lcmdv", function()
  vim.cmd("vnew")
  vim.cmd("setfiletype lua")
end, {})
vim.api.nvim_create_user_command("Lcmdh", function()
  vim.cmd("new")
  vim.cmd("setfiletype lua")
end, {})
vim.api.nvim_create_user_command("Term", function()
  vim.cmd("new")
  vim.cmd("term")
end, {})
vim.api.nvim_create_user_command("Termv", function()
  vim.cmd("vnew")
  vim.cmd("term")
end, {})
vim.api.nvim_create_user_command("Termh", function()
  vim.cmd("new")
  vim.cmd("term")
end, {})

-- Diagnostics configuration
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

-- Hex and binary autocmds.
if vim.g.read_binary_with_xxd or false then
  local before_open_hex = function()
    require("hex").dump()
  end
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = { "*.bin", "*.o", "*.exe", "*.a" },
    callback = function()
      vim.cmd("setfiletype xxd")
      before_open_hex()
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "xxd",
    callback = before_open_hex,
  })
end

-- OSC52 to sync remote to local.
-- When yank triggered, it got wrapped by special chars, and iterm2 recognize it as
-- signal to be synced to clipboard.
-- So vim instance anywhere could sync to system clipboard. Including ssh remote.
local copy = function()
  if vim.v.event.operator == "y" then
    require("vim.ui.clipboard.osc52").copy('"')
  end
end

vim.api.nvim_create_autocmd("TextYankPost", { callback = copy })

-- disable barbecue (Context) showing atop of the window
require("barbecue.ui").toggle(false)

-- TODO: Link images altogether.
--[[Obsidian related autoCommands 

    Tool functions]]

-- Shell integration
vim.g.shell_run = function(cmd)
  local tmpfile = "/tmp/lua_execute_tmp_file"
  local exit = os.execute(cmd .. " > " .. tmpfile .. " 2> " .. tmpfile .. ".err")

  local stdout_file = io.open(tmpfile)
  local stdout = stdout_file:read("*all")

  local stderr_file = io.open(tmpfile .. ".err")
  local stderr = stderr_file:read("*all")

  stdout_file:close()
  stderr_file:close()

  return exit, stdout .. stderr
end

function CommandCheckBefore()
  -- osbdidian vault guard.
  if not vim.g.obsidian_functions_enabled then
    vim.notify("Obsidian not installed or functionality set off. Stopped.", vim.log.levels.ERROR)
    return
  end
  if not vim.g.obsidian_vault or vim.g.obsidian_vault == "" then
    vim.notify("vim.g.obsidian_vault is not set. Stopped.", vim.log.levels.ERROR)
    return
  end
end

function VaultMap(localName)
  return vim.g.obsidian_vault:gsub("/$", "") .. "/" .. vim.fn.fnamemodify(localName, ":t")
end

--[[Exposed Commands]]

-- Unlink the current file. (Remove hard link.)
vim.api.nvim_create_user_command("ObsUnlink", function()
  CommandCheckBefore()
  -- file type guard.
  local current_file = vim.fn.expand("%:p", nil, nil)
  vim.cmd([[ :w ]])
  if vim.fn.fnamemodify(current_file, ":e") ~= "md" then
    vim.notify("The current file is not a Markdown file. Stopped.", vim.log.levels.ERROR)
    return
  end
  local destination = VaultMap(current_file)

  -- hard link here. Removal of any side won't be removing the file.
  local cmd = string.format("rm %s", vim.fn.shellescape(destination))
  local success, std = vim.g.shell_run(cmd)
  if not success then
    vim.notify("Error Unlinking file: " .. (std or ""), vim.log.levels.ERROR)
    return
  else
    vim.notify("Link " .. destination .. " removed: " .. (std or ""), vim.log.levels.INFO)
  end
end, {})

-- Link the current file to obsidian vault.
vim.api.nvim_create_user_command("ObsOpen", function()
  CommandCheckBefore()

  -- file type guard.
  local current_file = vim.fn.expand("%:p", nil, nil)
  vim.cmd([[ :w ]])
  if vim.fn.fnamemodify(current_file, ":e") ~= "md" then
    vim.notify("The current file is not a Markdown file. Stopped.", vim.log.levels.ERROR)
    return
  end

  local destination = VaultMap(current_file)
  -- Check if link already exists.
  local f = io.open(destination, "r")
  if f == nil then
    -- hard link the original to destination. Removal of any side won't be removing the file.
    local cmd = string.format("ln %s %s", vim.fn.shellescape(current_file), vim.fn.shellescape(destination))
    local success, std = vim.g.shell_run(cmd)
    if not success then
      vim.notify("Error linking file: " .. (std or ""), vim.log.levels.ERROR)
      return
    else
      vim.notify("Linked " .. current_file .. " to " .. destination .. (std or ""), vim.log.levels.INFO)
    end
  else
    io.close(f)
  end

  -- No need to switch there. Currently we can't ObsidianOpen a file with lcd out of vault.
  -- switch to the linked file for full functionality.
  --[[vim.cmd("edit " .. vim.fn.shellescape(destination))
  vim.cmd("bdelete " .. vim.fn.bufnr(current_file))
  vim.notify("Switch to linked file in vault: " .. destination, vim.log.levels.INFO)]]
  -- Open from obs
  -- vim.cmd("ObsidianOpen")
end, {})
