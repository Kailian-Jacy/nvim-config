-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Start a tmux session in the background if none.
-- TODO: Not sure if working.
vim.schedule(function()
  vim.fn.system("tmux", { "new", "-As0" })
end)

-- Open the launch.json related to the current workdir. If non-exists, confirms to create.
vim.api.nvim_create_user_command("OpenLaunchJson", function()
  -- Check if $VIMPWD/.vscode/launch.json exists.
  local vscode_dir = vim.fn.getcwd() .. "/.vscode"
  local launch_json = vscode_dir .. "/launch.json"

  if vim.fn.filereadable(launch_json) == 0 then
    -- Popup select to confirm creation. Map to [Y]es or [N]o.
    local choice = vim.fn.confirm("launch.json does not exist. Create it?", "&Yes\n&No", 1)
    if choice == 1 then
      -- Create basic launch.json template
      local template = [[
{
  "version": "0.2.0",
  "configurations": []
}
]]
      -- Create directory if it doesn't exist
      if vim.fn.isdirectory(vscode_dir) == 0 then
        vim.fn.mkdir(vscode_dir, "p")
      end
      local file = io.open(launch_json, "w")
      if file then
        file:write(template)
        file:close()
        vim.print_silent("Created $pwd/.vscode/launch.json")
      else
        vim.notify("Failed to create launch.json", vim.log.levels.ERROR)
        return
      end
    else
      vim.print_silent("aborted.")
      return
    end
  end

  vim.cmd("edit " .. launch_json)
end, { desc = "Open the launch.json related to the current workdir. If non-exists, confirms to create." })

-- Open and edit the lua script.
vim.api.nvim_create_user_command("SnipEdit", function()
  local default_snip_path = vim.fn.stdpath("config") .. "/snip/all.json"
  if vim.fn.filereadable(default_snip_path) == 1 then
    vim.cmd("e " .. default_snip_path)
  elseif vim.g.import_user_snippets and #vim.g.user_vscode_snippets_path > 0 then
    vim.cmd("e " .. vim.g.user_vscode_snippets_path[1])
  else
    vim.notify("Failed to open luasnippet file. ", vim.log.levels.ERROR)
    return
  end
  vim.print_silent("Editing lua script. Call :LuaSnippetsLoad on accomplishment.")
end, { desc = "Open the lua snippet buffer. By default, open the all.json under vim config dir." })

vim.api.nvim_create_user_command("SnipLoad", function()
  if vim.g.import_user_snippets then
    require("luasnip.loaders.from_vscode").load({
      paths = vim.g.user_vscode_snippets_path,
    })
    vim.print_silent("snip load success.")
  end
end, { desc = "Load luasnip files." })

-- Snippet picker.
vim.api.nvim_create_user_command("SnipPick", function()
  Snacks.picker.pick({
    supports_live = false,
    title = "Code Snippets",
    preview = "preview",
    format = function(item)
      return {
        { item.name, item.ft == "" and "Conceal" or "DiagnosticWarn" },
        { item.description },
      }
    end,
    finder = function()
      local snippets = {}
      for _, snip in ipairs(require("luasnip").get_snippets().all) do
        snip.ft = ""
        table.insert(snippets, snip)
      end
      for _, snip in ipairs(require("luasnip").get_snippets(vim.bo.ft)) do
        snip.ft = vim.bo.ft
        table.insert(snippets, snip)
      end
      local align_1 = 0
      for _, snip in pairs(snippets) do
        align_1 = math.max(align_1, #snip.name)
      end
      local items = {}
      for _, snip in pairs(snippets) do
        local docstring = snip:get_docstring()
        if type(docstring) == "table" then
          docstring = table.concat(docstring)
        end
        local name = Snacks.picker.util.align(snip.name, align_1 + 5)
        local description = table.concat(snip.description)
        description = name == description and "" or description
        table.insert(items, {
          text = name .. description,
          name = name,
          description = description,
          trigger = snip.trigger,
          orig_snip = snip,
          ft = snip.ft,
          preview = {
            ft = snip.ft,
            text = docstring,
          },
        })
      end
      return items
    end,
    -- Insert trigger and tab to expand later.
    confirm = function(picker, item)
      picker:close()
      -- TODO: Consider about insertion.
      -- Now just put in reg.
      -- Now expansion is sometimes causing panic.
      vim.fn.setreg('"', item.trigger)
    end,
  })
end, { desc = "Snacks picker for luasnip." })

-- Lua print target result content.
vim.api.nvim_create_user_command("LuaPrint", function()
  local codepiece, err = loadstring("vim.print(" .. vim.g.function_get_selected_content() .. ")")
  if err then
    vim.print("failed to execute target string: " .. err)
  else
    codepiece()
  end
end, { desc = "Execute the target lua codepiece and print result", range = true })

-- Yanky ring filter
if not vim.g.yanky_ring_accept_length then
  vim.notify("vim.g.yanky_ring_accept_length is not set. Default to be 10.")
  vim.g.yanky_ring_accept_length = 10
end
if not vim.g.yanky_ring_max_accept_length then
  vim.notify("vim.g.yanky_ring_max_accept_length is not set. Default to be 1000.")
  vim.g.yanky_ring_max_accept_length = 1000
end

---@param copied_content string
---@return string|nil
local _yanky_hook_before_copy_body = function(copied_content)
  if #vim.trim(copied_content) < vim.g.yanky_ring_accept_length then
    return nil
  end
  if #vim.trim(copied_content) > vim.g.yanky_ring_max_accept_length then
    return nil
  end
  return copied_content
end

local _yanky_hook_before_copy = function()
  -- get the copied content from default register.
  local content = _yanky_hook_before_copy_body(vim.fn.getreg('"'))

  -- Actually move the filtered content to yanky register.
  require("yanky.history").push({
    regcontents = content,
    regtype = "y",
  })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  pattern = "*",
  callback = function()
    local reg = vim.v.event.regname
    -- If the default register (nil for default '"')
    if reg == nil or #reg == 0 then
      _yanky_hook_before_copy()
    end
  end,
})

-- Oldfiles related.
-- Save & load the pages in record after entering buffer.
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  -- Async write and load shada files.
  callback = vim.schedule_wrap(function()
    vim.cmd([[ wshada ]])
    vim.cmd([[ rshada! ]])
  end),
})

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
    title = title .. " (Global)"
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
          if oldfile:find("^term:/") or oldfile:find("^scp:/") or oldfile:find("^rsync:/") then
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

-- Drop buf somewhere and reveal the last on this window.
vim.api.nvim_create_user_command("ThrowAndReveal", function(opt)
  if #opt.args == 0 then
    opt = "l" -- "l: right"
  else
    opt = opt.args
  end
  local buf = vim.api.nvim_get_current_buf()
  if not vim.tbl_contains({ "h", "j", "k", "l" }, opt) then
    vim.notify("Invalid direction: " .. opt, vim.log.levels.WARN)
  end
  -- create new window if none exists.
  if opt == "l" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("vsplit")
    end
    vim.cmd("wincmd l")
  elseif opt == "h" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("vsplit")
    end
  elseif opt == "j" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("split")
    end
    vim.cmd("wincmd j")
  elseif opt == "k" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("split")
    end
  end
  vim.cmd("b " .. buf)

  vim.cmd("wincmd p") -- go to the last win.
  require("bufjump").backward()

  vim.cmd("wincmd p") -- focus to the created win.
end, { nargs = "?" })

-- Open in Vscode
vim.api.nvim_create_user_command("Code", function(opt)
  local mode
  if #opt.args == 0 then
    mode = "full"
  else
    mode = opt.args
  end

  -- Try to check if code executable exists.
  local code = "Code"
  if not vim.fn.executable(code) then
    vim.notify(
      '`code` not found in executable. Install with "Shell Command: Install Command `code` in PATH"',
      vim.log.levels.ERROR
    )
    return
  end

  local file
  local dir

  if mode == "file" then
    file = vim.fn.expand("%:p")
  elseif mode == "dir" then
    dir = vim.fn.getcwd()
  elseif mode == "both" then
    file = vim.fn.expand("%:p")
    dir = vim.fn.getcwd()
  else
    vim.notify("Invalid option for code: " .. mode .. '. Alternatives: "file"(default), "dir", "both"')
    return
  end

  if dir then
    vim.print(dir)
    vim.loop.spawn(code, {
      args = { dir },
    })
  end
  if file then
    vim.loop.spawn(code, {
      args = { file },
    })
  end
end, { desc = "Open the current file or dir in vscode.", nargs = "?" })

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
