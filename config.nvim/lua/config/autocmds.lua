-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Start a tmux session in the background if none.
-- TODO: Not sure if working.
vim.schedule(function()
  vim.fn.system("tmux", { "new", "-As0" })
end)

-- Quickfix related.
-- Page closing
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf" },
  callback = function()
    vim.keymap.set(
      "n",
      "q",
      "<cmd>bd<cr>",
      { desc = "Using q to close quickfix page.", silent = true, buffer = true, noremap = false }
    )
  end,
})
vim.api.nvim_create_user_command("Qnext", function()
  local success = pcall(vim.cmd, "cnext")
  if not success then
    vim.cmd("cfirst")
  end
end, { desc = "navigate to the next quickfix item" })
vim.api.nvim_create_user_command("Qprev", function()
  local success = pcall(vim.cmd, "cprev")
  if not success then
    vim.cmd("clast")
  end
end, { desc = "navigate to the next quickfix item" })
vim.api.nvim_create_user_command("Qnewer", function()
  local _ = pcall(vim.cmd, "cnewer")
end, { desc = "navigate to the next quickfix list" })
vim.api.nvim_create_user_command("Qolder", function()
  local _ = pcall(vim.cmd, "colder")
end, { desc = "navigate to the next quickfix list" })

-- Help page closing.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "man" },
  callback = function()
    vim.keymap.set(
      "n",
      "q",
      "<c-w>c",
      { desc = "Using q to close help and man page.", silent = true, buffer = true, noremap = false }
    )
  end,
})

-- Window splitting with cursor moved to the new one.
vim.api.nvim_create_user_command("Split", function ()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cmd>split<cr><c-w>j", true, false, true), "n", false)
end, { desc = "split horizontally and move cursor" })
vim.api.nvim_create_user_command("Vsplit", function ()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cmd>vsplit<cr><c-w>l", true, false, true), "n", false)
end, { desc = "split horizontally and move cursor" })

-- Highlight yanking
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  desc = "Hightlight selection on yank",
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 100 })
  end,
})

-- Old files picker.
local snack_old_file = function(opts)
  opts.global = opts.global or false
  local title = "OldFiles"
  local toggle_function
  if opts.global then
    title = title .. "(Global)"
    toggle_function = function(picker, _)
      vim.cmd([[ SnackOldfilesLocal ]])
      picker:close()
    end
  else
    toggle_function = function(picker, _)
      vim.cmd([[ SnackOldfilesGlobal ]])
      picker:close()
    end
  end

  return function()
    Snacks.picker.pick({
      title = title,
      format = function(item, picker)
        local ret = require("snacks.picker.format").filename(item, picker)
        -- ret[#ret + 1] = { item.text }
        return ret
      end,
      finder = function(_, _)
        local cwd = vim.fs.normalize(vim.fn.getcwd())
        local oldfile_items = vim.v.oldfiles
        if #oldfile_items == 0 then
          vim.print_silent("Oldfiles picker: No old files.")
          return {}
        end
        -- TODO: Compare if the path within the current working directory.

        local tbl = {}
        for _, oldfile in ipairs(oldfile_items) do
          local full_path = vim.fs.normalize(oldfile)
          if not opts.global and full_path:find(cwd, 1, true) ~= 1 then
            goto continue
          end
          if oldfile:find("^term:/") then
            goto continue
          end
          table.insert(tbl, {
            text = vim.fn.fnamemodify(oldfile, ":p:t"),
            _path = oldfile,
            file = oldfile,
          })
          ::continue::
        end
        return tbl
      end,
      actions = {
        toggle_local = toggle_function,
      },
      win = {
        input = {
          keys = {
            ["<c-g>"] = { "toggle_local", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            ["<c-g>"] = { "toggle_local", mode = { "n", "i" } },
          },
        },
      },
    })
  end
end

vim.api.nvim_create_user_command(
  "SnackOldfilesGlobal",
  snack_old_file({ global = true }),
  { desc = "Open oldfiles in global" }
)
vim.api.nvim_create_user_command(
  "SnackOldfilesLocal",
  snack_old_file({ global = false }),
  { desc = "Open oldfiles in local working directory" }
)

-- Bookmark related code snippet.
vim.api.nvim_create_user_command("BookmarkSnackPicker", function()
  Snacks.picker.pick({
    title = "Bookmarks",
    format = function(item, picker)
      local ret = require("snacks.picker.format").filename(item, picker)
      ret[#ret + 1] = { item.text }
      return ret
    end,
    finder = function(_, _)
      local bookmark_items = require("bookmarks.domain.node").get_all_bookmarks(
        require("bookmarks.domain.repo").ensure_and_get_active_list()
      )
      local tbl = {}
      for _, bookmark in ipairs(bookmark_items) do
        table.insert(tbl, {
          text = bookmark.name,
          _path = bookmark.location.path,
          _bookmark = bookmark,
          -- = bookmark.location,
          pos = { bookmark.location.line, bookmark.location.col },
          bm_location = bookmark.location,
          file = bookmark.location.path,
        })
      end
      return tbl
    end,
    actions = {
      delete_from_bookmarks = function(picker, item)
        local location = item.bm_location
        local node = require("bookmarks.domain.repo").find_node_by_location(location)
        if not node then
          vim.notify("No node found at cursor position", vim.log.levels.WARN)
          return
        end
        require("bookmarks.domain.service").delete_node(node.id)
        require("bookmarks.sign").safe_refresh_signs()
        picker.list:set_selected()
        picker.list:set_target()
        picker:find()
      end,
      edit_bookmark = function(picker, item)
        -- Get the desc of of bookmark
        local text = "Original text name"
        vim.ui.input({
          prompt = "Edit Bookmark Name",
          -- icon = " ",
          -- icon_pos = "title",
          default = text,
        }, function(value)
          vim.print(value)
          if not value then
            vim.print("Bookmark unchanged.")
            return
          end
          if value and (#value == 0 or value == text) then
            vim.print("Bookmark unchanged.")
            return
          end
          -- Create the bookmark.
          item._bookmark.name = value
          require("bookmarks.domain.service").rename_node(item._bookmark.id, value)
          -- Refresh the picker.
          picker.list:set_selected()
          picker.list:set_target()
          picker:find()
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-d>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<c-e>"] = { "edit_bookmark", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<c-d>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["dd"] = { "delete_from_bookmarks", mode = { "n" } },
          ["<c-e>"] = { "edit_bookmark", mode = { "n", "i" } },
          ["ee"] = { "edit_bookmark", mode = { "n" } },
        },
      },
    },
  })
end, { desc = "Bookmark table in snacks.picker" })

vim.api.nvim_create_user_command("BookmarkEditNameAtCursor", function()
  local location = require("bookmarks.domain.location").get_current_location()
  local node = require("bookmarks.domain.repo").find_node_by_location(location)
  if not node then
    vim.notify("No node found at cursor position", vim.log.levels.WARN)
    return
  end
  local text = "Original text name"
  vim.ui.input({
    prompt = "Edit Bookmark Name",
    default = text,
  }, function(value)
    vim.print(value)
    if not value then
      vim.print("Bookmark unchanged.")
      return
    end
    if value and (#value == 0 or value == text) then
      vim.print("Bookmark unchanged.")
      return
    end
    -- Create the bookmark.
    node.name = value
    require("bookmarks.domain.service").rename_node(node.id, value)
    require("bookmarks.sign").safe_refresh_signs()
  end)
end, { desc = "Edit the current bookmark under the cursor." })

vim.api.nvim_create_user_command("DeleteBookmarkAtCursor", function()
  local location = require("bookmarks.domain.location").get_current_location()
  local node = require("bookmarks.domain.repo").find_node_by_location(location)
  if not node then
    vim.notify("No node found at cursor position", vim.log.levels.WARN)
    return
  end
  require("bookmarks.domain.service").delete_node(node.id)
  require("bookmarks.sign").safe_refresh_signs()
end, { desc = "Remove the bookmark at cursor line." })

-- Set cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
if vim.fn.has("nvim-0.11") == 1 then
  -- Neovim added t mode for guicursor in nvim-0.11, and gave up drawing terminal mode.
  vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:ver25"
end

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

-- Search History
vim.api.nvim_create_user_command("SearchHistory", Snacks.picker.search_history, {})

-- Drop buf some where and reveal the last.
vim.api.nvim_create_user_command("ThrowAndReveal", function(opt)
  if #opt.args == 0 then
    opt = "l"
  else
    opt = opt.args
  end
  local buf = vim.api.nvim_get_current_buf()
  if not vim.tbl_contains({ "h", "j", "k", "l" }, opt) then
    vim.notify("Invalid direction: " .. opt, vim.log.levels.WARN)
  end
  if vim.fn.winnr() ~= vim.fn.winnr(opt) then
    -- exists. Just throw.
    vim.cmd("wincmd " .. opt)
  else
    -- create new window if none exists.
    if opt == "l" then
      vim.cmd("vsplit")
    elseif opt == "h" then
      vim.cmd("vsplit")
      vim.cmd("wincmd h")
    elseif opt == "j" then
      vim.cmd("split")
    elseif opt == "k" then
      vim.cmd("split")
      vim.cmd("wincmd k")
    end
  end
  vim.cmd("b " .. buf)
  vim.cmd("wincmd p") -- go to the last win.
  require("bufjump").backward()
end, { nargs = "?" })

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
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.g.LAST_WORKING_DIRECTORY then
      -- vim.print_silent("Workdir: " .. vim.g.LAST_WORKING_DIRECTORY)
      vim.cmd("cd " .. (vim.g.LAST_WORKING_DIRECTORY or ""))
    end
  end,
})
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
