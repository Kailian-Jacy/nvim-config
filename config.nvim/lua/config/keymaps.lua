-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.g.mapleader = " "

-- Asterisk do not move to the next automatically.
-- TODO: find a way to check highlights under the cursor. Go to the next one on highlight.
vim.keymap.set({ "n" }, "*", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("*``", true, false, true), "n", false)
end, { desc = "Search and highlight but not jump to the next.", noremap = true })

-- Paste to cmd + v
-- vim.api.nvim_set_keymap("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<D-v>", '<C-\\><C-o>"+p', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("c", "<D-v>", "<C-r>+", { noremap = true, silent = true })

-- Local workaround for osc52 copy from remote.
vim.keymap.set({ "n", "v" }, "D", '"*d')
vim.keymap.set({ "n", "v" }, "Y", '"*y')

-- Command mode keymaps:
vim.keymap.set("c", "<c-e>", "<end>", { desc = "move cursor to the end" })
vim.keymap.set("c", "<c-a>", "<home>", { desc = "move cursor to the end" })

-- Path/Line fetching keymap.
vim.keymap.set({ "v", "n", "x" }, "<leader>yp", "<cmd>CopyFilePath full<cr>", { desc = "Copy full path" })
vim.keymap.set({ "v", "n", "x" }, "<leader>yr", "<cmd>CopyFilePath relative<cr>", { desc = "Copy relative path" })
vim.keymap.set({ "v", "n", "x" }, "<leader>yf", "<cmd>CopyFilePath filename<cr>", { desc = "Copy filename only" })
vim.keymap.set({ "v", "n", "x" }, "<leader>yl", "<cmd>CopyFilePath line<cr>", { desc = "Copy filename:line number" })

-- Inc rename.
vim.keymap.set("v", "<leader>rn", '"zy:IncRename <c-r>z', { desc = "Visual mode lsp variable name replacement." })

-- keymap based on filetype
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "cpp", "c", "objc", "objcpp", "cuda", "proto" },
  callback = function()
    vim.keymap.set({ "n" }, "<leader>hh", function()
      vim.cmd("ClangdSwitchSourceHeader") -- remind: this is async..
    end, { desc = "Switch between .h and .c" })
  end,
})

-- Some useful keymaps:
vim.keymap.set({ "n", "v" }, "<leader>-", "<cmd>split<cr><c-w>j")
vim.keymap.set({ "n", "v" }, "<leader>|", "<cmd>vsplit<cr><c-w>l")
vim.keymap.set({ "n", "v" }, "<leader>wd", "<c-w>q", { desc = "Close the current window." })
vim.keymap.set({ "n", "v" }, "<esc>", function()
  vim.cmd([[ noh ]])
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
end, { desc = "Esc wrapper: no highlight with esc." })

vim.keymap.set({ "n", "v" }, "<leader>ps", '"+p', { desc = "paste from the clipboard." })

-- Window maximize.
vim.keymap.set({ "n", "v" }, "<leader>wm", function()
  local cmd
  if vim.t.window_maximized then
    cmd = "<c-w>="
    vim.t.window_maximized = false
  else
    vim.t.window_maximized = true
    cmd = "<c-w>_<c-w>|"
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), "n", false)
  require("lualine").refresh()
end)

-- local Util = require("lazyvim.util")
-- local lazyterm = function()
--   Util.terminal({ "tmux", "new", "-As0" }, { cwd = Util.root() })
-- end
-- vim.keymap.set("n", "<C-/>", lazyterm, { desc = "Terminal (root dir)" })
-- vim.keymap.set("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide Terminal" })

-- Commenting keymaps
vim.keymap.set({ "v", "n" }, "<leader>cm", function()
  if vim.fn.mode() == "n" then
    vim.api.nvim_input("gcc")
  else
    -- Comment and do not cancel last visual selection
    vim.api.nvim_input("gc")
    vim.api.nvim_input("gv")
  end
end)

if vim.g.modules.svn and vim.g.modules.svn.enabled then
  vim.keymap.set("n", "<leader>sd", function()
    local tab_debug = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug")
    if tab_debug == true then
      vim.cmd([[SvnDiffThisClose]])
    else
      vim.cmd([[SvnDiffThis]])
    end
  end, { noremap = true, desc = "Svn diff this" })
end
-- vim.keymap.set("n", "<leader>sa", "<cmd>SvnDiffAll<cr>", { noremap = true, desc = "Svn diff all" }) -- It's better to use autocmd

-- Do not move line with alt. Sometimes it's triggered by esc j/k
-- vim.keymap.del({ "n", "i", "v" }, "<M-k>")
-- vim.keymap.del({ "n", "i", "v" }, "<M-j>")

vim.keymap.set({ "n", "i", "v" }, "<c-i>", "<c-i>")

-- Exit keymap.
vim.keymap.set("n", "ZA", function()
  vim.cmd([[ wqa ]])
end, { noremap = true })

-- as exiting vim with running jobs seems dangerous, I choose to use :qa! to explicitly do so.

-- Git related
vim.keymap.set("n", "<leader>G", "<cmd>LazyGit<CR>", { noremap = true, silent = true })

-- Navigation: Cursor wandering around
vim.keymap.set({ "n", "v", "i" }, "<C-J>", "<cmd>wincmd j<cr>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-H>", "<cmd>wincmd h<cr>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-L>", "<cmd>wincmd l<cr>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-K>", "<cmd>wincmd k<cr>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-BS>", "<cmd>wincmd p<cr>", { noremap = true, silent = true }) --it won't go across tabs. useless.
vim.keymap.set({ "t" }, "<C-L>", "<c-\\><c-n><c-w>l", { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-H>", "<c-\\><c-n><c-w>h", { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-J>", "<c-\\><c-n><c-w>j", { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-K>", "<c-\\><c-n><c-w>k", { noremap = true, silent = true })

-- Throw buffer and reveal. Special-cased in terminal mode.
vim.keymap.set({ "n", "v", "i" }, "<C-S-l>", function()
  if require("terminal") and require("terminal").__customize.is_currently_focusing_on_terminal() then
    require("terminal").__customize.shift_right()
  else
    vim.cmd([[ThrowAndReveal l]])
  end
end, { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-S-k>", function()
  if require("terminal") and require("terminal").__customize.is_currently_focusing_on_terminal() then
    require("terminal").__customize.shift_up()
  else
    vim.cmd([[ThrowAndReveal k]])
  end
end, { noremap = true, silent = true })

vim.keymap.set({ "n", "v", "i" }, "<C-S-j>", function()
  if require("terminal") and require("terminal").__customize.is_currently_focusing_on_terminal() then
    require("terminal").__customize.shift_down()
  else
    vim.cmd([[ThrowAndReveal j]])
  end
end, { noremap = true, silent = true })

vim.keymap.set({ "n", "v", "i" }, "<C-S-h>", function()
  if require("terminal") and require("terminal").__customize.is_currently_focusing_on_terminal() then
    require("terminal").__customize.shift_left()
  else
    vim.cmd([[ThrowAndReveal h]])
  end
end, { noremap = true, silent = true })

-- Quick fixes.
vim.keymap.set(
  { "n", "v" },
  "<leader>qj",
  "<cmd>Qnext<cr>",
  { desc = "navigate to the next quickfix item", noremap = true, silent = true }
)
vim.keymap.set(
  { "n", "v" },
  "<leader>qk",
  "<cmd>Qprev<cr>",
  { desc = "navigate to the prev quickfix item", noremap = true, silent = true }
)
vim.keymap.set(
  { "n", "v" },
  "<leader>ql",
  "<cmd>Qnewer<cr>",
  { desc = "navigate to the newer quickfix item", noremap = true, silent = true }
)
vim.keymap.set(
  { "n", "v" },
  "<leader>qh",
  "<cmd>Qolder<cr>",
  { desc = "navigate to the older quickfix item", noremap = true, silent = true }
)

-- search
vim.keymap.set("v", "/", '"fy/\\V<C-R>f<CR>')
-- vim.keymap.set(
--   "v",
--   "<leader>/",
--   require("telescope-live-grep-args.shortcuts").grep_visual_selection,
--   { noremap = true }
-- )
-- nnoremap <leader>/ <cmd>Telescope live_grep<cr>
-- vnoremap <leader>/ "zy:Telescope live_grep default_text=<C-r>z<cr>
vim.keymap.set("n", "gh", function()
  local winid = require("ufo").peekFoldedLinesUnderCursor()
  if not winid then
    vim.lsp.buf.hover()
  end
end)
-- vim.keymap.set("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "ge", "<cmd>lua vim.diagnostic.open_float()<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", { noremap = true, silent = true })

-- disable lazyim default keymaps.
-- vim.keymap.del("n", "<leader>l")
-- vim.keymap.del("n", "<leader>L")

-- copilot mapping: copilot mapping are all migrated to the configuration part of nvim-cmp.
vim.g.copilot_no_maps = true

-- buffer related
local close_buf_but_leave_window = function()
  -- vim.cmd([[ bp | sp | bn | bd! ]])
  Snacks.bufdelete()
end
local close_buf_and_window = function()
  vim.cmd([[ bd! ]])
end
vim.keymap.set("n", "<leader>bd", function()
  -- Closing debugging terminal. Close without confirmation.
  if vim.fn.bufname() == "[dap-terminal] Debug" then
    close_buf_and_window()
    return
  end
  if vim.bo.modified and vim.fn.wordcount()["words"] ~= 0 then
    vim.print_silent("To close edited buf, use :bd! to confirm.", vim.log.levels.INFO)
    return
  end
  -- Not sure this is correct... but it works for now. Just leave it.
  --
  -- if #vim.fn.getbufinfo({ bufloaded = true }) == 1 and #vim.api.nvim_list_tabpages() == 1 then
  --   vim.notify("last buf.", vim.log.levels.WARN)
  --   return
  -- end
  close_buf_but_leave_window()
end, { noremap = true, silent = false })

-- Tab-related.
vim.keymap.set("n", "<leader><tab>", "<cmd>tabnew<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab>", "<cmd>FlipPinnedTab<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "d<tab>", "<cmd>tabclose<CR>", { noremap = true, silent = true })

-- Migrate to normal-tabbing switching.
vim.keymap.set("n", "<C-tab>", "<cmd>tabnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-C-tab>", "<cmd>tabprev<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>up", function()
  if vim.g.pinned_tab and vim.api.nvim_get_current_tabpage() == vim.g.pinned_tab.id then
    -- Call on the pinned tab. Unpin it.
    vim.cmd("UnpinTab")
  else
    -- Pin the tab elsewise.
    vim.cmd("PinTab")
  end
end, { noremap = true, silent = true })
vim.keymap.set("n", "<leader>uP", ":PinTab ", { noremap = true, silent = true })

-- context display
vim.keymap.set({ "n", "i", "x" }, "<C-G>", function()
  vim.print_silent(require("nvim-navic").get_location() or "N.A.")
end)

-- Mapping and unmapping during debugging.
vim.g.nvim_dap_noui_backup_keymap = nil

local rhs_options = {}
function rhs_options:map_cr(cmd_string)
  self.cmd = (":%s<CR>"):format(cmd_string)
  return self
end

vim.g.nvim_dap_keymap = function()
  -- Prevent keymapping set during keymap.
  if vim.g.nvim_dap_noui_backup_keymap ~= nil then
    vim.print_silent("Already in debugging keymap.")
    return
  end

  vim.g.nvim_dap_noui_backup_keymap = vim.api.nvim_get_keymap("n")
  local widgets = require("dap.ui.widgets")
  vim.g.nvim_dap_noui_keymap_list = {
    -- DAP --
    -- run
    -- ['r'] = { f = require('go.dap').run, desc = 'run' },
    ["c"] = { f = require("dap").continue, desc = "continue" },
    ["n"] = { f = require("dap").step_over, desc = "step_over" },
    ["s"] = { f = require("dap").step_into, desc = "step_into" },
    ["o"] = { f = require("dap").step_out, desc = "step_out" },
    ["u"] = { f = require("dap").up, desc = "up" },
    ["d"] = { f = require("dap").down, desc = "down" },

    -- Widgets for resources.
    ["<D-f>"] = {
      f = function()
        widgets.centered_float(widgets.frames)
      end,
      desc = "Widget: Frames",
    },
    ["<D-s>"] = {
      f = function()
        widgets.centered_float(widgets.sessions)
      end,
      desc = "Widget: Session",
    },
    ["<D-p>"] = {
      f = function()
        widgets.centered_float(widgets.scopes)
      end,
      desc = "Widget: Variable in Scopes",
    },
    -- TODO:  Breakpoints & conditional breakpoints waits to be finished
    --
    -- ["<D-b>"] = { f = widgets.centered_float(widgets.break), desc = "Widget: Variable in Scopes" },
    ["<D-r>"] = { f = require("dap").repl.toggle, desc = "repl toggle" },

    ["C"] = { f = require("dap").run_to_cursor, desc = "run_to_cursor" },
    ["b"] = { f = require("dap").toggle_breakpoint, desc = "toggle_breakpoint" },

    ["S"] = { f = require("dap").terminate, desc = "stop debug session" },
    ["<c-c>"] = { f = require("dap").pause, desc = "pause" },

    ["P"] = { f = require("dap.ui.widgets").preview, m = { "n", "v" }, desc = "preview the content" },
    ["p"] = { f = require("dap.ui.widgets").hover, m = { "n", "v" }, desc = "hover" },
  }

  for key, value in pairs(vim.g.nvim_dap_noui_keymap_list) do
    local mode, keymap = key:match("([^|]*)|?(.*)")
    if type(value) == "string" then
      value = rhs_options.map_cr(value):with_noremap():with_silent()
    end
    if type(value) == "table" and value.f then
      local m = value.m or "n"
      vim.keymap.set(m, key, value.f)
    end
    if type(value) == "table" and value.cmd then
      local rhs = value.cmd
      local options = value.options
      vim.api.nvim_set_keymap(mode, keymap, rhs, options)
    end
  end
end

vim.g.nvim_dap_upmap = function()
  if vim.g.nvim_dap_noui_backup_keymap == nil then
    vim.print_silent("Already left debugging keymap.")
    return
  end

  for value, _ in pairs(vim.g.nvim_dap_noui_keymap_list) do
    local cmd = "silent! unmap " .. value
    vim.cmd(cmd)
  end

  vim.cmd([[silent! vunmap p]])

  for k, _ in pairs(vim.g.nvim_dap_noui_keymap_list) do
    for _, v in pairs(vim.g.nvim_dap_noui_backup_keymap or {}) do
      if v.lhs == k then
        local nr = (v.noremap == 1)
        local sl = (v.slient == 1)
        local exp = (v.expr == 1)
        local mode = v.mode
        local desc = v.desc or "dap noui keymap"
        if v.mode == " " then
          mode = { "n", "v" }
        end

        vim.keymap.set(mode, v.lhs, v.rhs or v.callback, { noremap = nr, silent = sl, expr = exp, desc = desc })
        -- vim.api.nvim_set_keymap('n', v.lhs, v.rhs, {noremap=nr, silent=sl, expr=exp})
      end
    end
  end
  vim.g.nvim_dap_noui_backup_keymap = nil
end

-- check if debug session activating
local isInDebugging = function()
  if not package.loaded.dap then
    return false
  end
  local session = require("dap").session()
  return session ~= nil
end

-- NoUIGenericDebug
function NoUIGeneircDebug()
  -- Invoke debugging. dap.ext.vscode.launch_js reads the launch debug file;
  -- Choose debug file for debugging.
  -- Set Keymap for debugging
  if isInDebugging() then
    vim.print_silent("Session is already activated.")
    return
  end
  -- (Re-)reads launch.json if present
  -- Try to find existing launch.json first
  local launch_json, vscode_dir = vim.g.find_launch_json(vim.fn.getcwd())

  -- If not found, use current working directory for creation
  if not launch_json then
    vscode_dir = vim.fn.getcwd() .. "/.vscode"
    launch_json = vscode_dir .. "/launch.json"
  end

  if vim.fn.filereadable(launch_json) then
    require("dap.ext.vscode").load_launchjs(launch_json, {
      debugpy = { "python" },
      cpptools = { "c", "cpp" },
    })
  end
  require("dap").continue()
end

vim.keymap.set("n", "<leader>DD", NoUIGeneircDebug)
vim.keymap.set("n", "<leader>Dt", "<cmd>DapTerminate<CR>")

-- Debugging keymaps set/unset.
vim.keymap.set({ "n", "v", "x" }, "<leader>dD", function()
  if vim.g.debugging_keymap == true then
    vim.g.nvim_dap_upmap()
    vim.g.debugging_keymap = false
  else
    vim.g.nvim_dap_keymap()
    vim.g.debugging_keymap = true
  end
  require("lualine").refresh()
end, { desc = "Toggle debugging keymaps mode." })

-- Cmd-related mappings.
---@class CmdMapping
---@field cmdKeymap string
---@field leaderKeymap string
---@field modes table
---@field description string
---@field no_insert_mode boolean | nil @default false
---@field back_to_insert boolean | nil @default false

---@type table<CmdMapping>
local cmd_mappings = {
  -- Ai related.
  { cmdKeymap = "<D-a>", leaderKeymap = "<leader>ae", modes = { "n", "v" }, description = "Revoke ai to modify" },
  { cmdKeymap = "<D-A>", leaderKeymap = "<leader>aa", modes = { "n", "v" }, description = "AI panel" },
  -- Buffer related.
  { cmdKeymap = "<D-b>", leaderKeymap = "<leader>bb", modes = { "n", "v" }, description = "List all buffers." },
  { cmdKeymap = "<D-B>", leaderKeymap = "<leader>bB", modes = { "n", "v" }, description = "Grep in all buffers." },
  -- Comment related.
  { cmdKeymap = "<D-c>", leaderKeymap = "<leader>cm", modes = { "n", "v" }, description = "Comment" },
  -- Debugging related.
  {
    cmdKeymap = "<D-D>",
    leaderKeymap = "<leader>dD",
    modes = { "n", "v", "i" },
    description = "Toggle debug keymaps",
    back_to_insert = true,
  },
  -- Directory/file related
  {
    cmdKeymap = "<D-e>",
    leaderKeymap = "<leader>fe",
    modes = { "n", "v" },
    description = "List directory on current dir.",
  },
  {
    cmdKeymap = "<D-E>",
    leaderKeymap = "<leader>fE",
    modes = { "n", "v" },
    description = "List directory on current file base dir.",
  },
  -- TODO: Directory from the current opened buffer.
  -- {
  --   cmdKeymap = "<D-E>",
  --   leaderKeymap = "<leader>ee",
  --   modes = { "n", "i" },
  --   description = "Telescope directory on Working directory.",
  -- },
  { cmdKeymap = "<D-f>", leaderKeymap = "<leader>ff", modes = { "n", "v" }, description = "List all files." },
  -- { cmdKeymap = "<D-F>", leaderKeymap = "<leader>fF", modes = { "n" }, description = "Search in the working directory" },
  -- Git
  {
    cmdKeymap = "<D-g>",
    leaderKeymap = "<leader>hp",
    modes = { "n" },
    description = "Preview Hunk",
    back_to_insert = true,
  },
  { cmdKeymap = "<D-G>", leaderKeymap = "<leader>gd", modes = { "n" }, description = "Git diffing" },
  -- Messages
  { cmdKeymap = "<D-i>", leaderKeymap = "<leader>im", modes = { "n" }, description = "History messages" },
  -- Diagnostics
  { cmdKeymap = "<D-j>", leaderKeymap = "<leader>jj", modes = { "n" }, description = "Show buffer diagnostics" },
  { cmdKeymap = "<D-J>", leaderKeymap = "<leader>jJ", modes = { "n" }, description = "Workspace diagnostics" },
  -- Keymaps
  -- { cmdKeymap = "<D-l>", leaderKeymap = "<leader>ll", modes = { "n", "v" }, description = "Inspect in line mode." },
  -- Inspect
  { cmdKeymap = "<D-k>", leaderKeymap = "<leader>sk", modes = { "n" }, description = "List keymaps" },
  -- Task management
  { cmdKeymap = "<D-l>", leaderKeymap = "<leader>ll", modes = { "n" }, description = "Review last task output" },
  { cmdKeymap = "<D-L>", leaderKeymap = "<leader>lL", modes = { "n" }, description = "Task list" },
  -- Bookmarks
  { cmdKeymap = "<D-M>", leaderKeymap = "<leader>sm", modes = { "n", "v" }, description = "List keymaps" },
  -- New buffer/instances.
  { cmdKeymap = "<D-n>", leaderKeymap = "<cmd>enew<CR>", modes = { "n" }, description = "New buffer." },
  {
    cmdKeymap = "<D-N>",
    leaderKeymap = "<cmd>NeovideNew<CR>",
    modes = { "n", "v" },
    description = "New neovide instance.",
  },
  {
    cmdKeymap = "<D-o>",
    leaderKeymap = "<leader>wm",
    modes = { "n", "v" },
    description = "Toggle maximize window",
    back_to_insert = true,
  },
  { cmdKeymap = "<D-O>", leaderKeymap = "<leader>fo", modes = { "n", "v" }, description = "Visited files" },
  -- Command related.
  { cmdKeymap = "<D-p>", leaderKeymap = "<leader>pp", modes = { "n", "v" }, description = "List history command" },
  {
    cmdKeymap = "<D-P>",
    leaderKeymap = "<leader>pP",
    modes = { "n", "v" },
    description = "All available command",
  },
  -- Search
  { cmdKeymap = "<D-r>", leaderKeymap = "<leader>rn", modes = { "n", "v" }, description = "LSP rename variable." },
  { cmdKeymap = "<D-R>", leaderKeymap = "<leader>cR", modes = { "n", "v" }, description = "Rename file" },
  -- Symbols
  {
    cmdKeymap = "<D-s>",
    leaderKeymap = "<leader>ss",
    modes = { "n", "v" },
    description = "List symbols (In Buffer)",
  },
  {
    cmdKeymap = "<D-S>",
    leaderKeymap = "<leader>sS",
    modes = { "n", "v" },
    description = "List symbols (Workspace)",
  },
  -- Terminal.
  {
    cmdKeymap = "<D-t>",
    leaderKeymap = "<leader>tt",
    modes = { "n", "v" },
    description = "Floating terminal in tmux.",
  },
  {
    cmdKeymap = "<D-s-l>",
    leaderKeymap = "<c-s-l>",
    modes = { "t" },
    description = "Move terminal to right split.",
  },
  {
    cmdKeymap = "<D-s-k>",
    leaderKeymap = "<c-s-k>",
    modes = { "t" },
    description = "Move terminal to top split.",
  },
  {
    cmdKeymap = "<D-s-h>",
    leaderKeymap = "<c-s-h>",
    modes = { "t" },
    description = "Move terminal to left split.",
  },
  {
    cmdKeymap = "<D-s-j>",
    leaderKeymap = "<c-s-j>",
    modes = { "t" },
    description = "Move terminal to bottom split.",
  },
  {
    cmdKeymap = "<d-bs>",
    leaderKeymap = "<c-bs>",
    modes = { "t" },
    description = "Reset terminal in tmux.",
  },
  -- Telescope recover.
  { cmdKeymap = "<D-T>", leaderKeymap = "<leader>tT", modes = { "n" }, description = "Reshow the last list" },
  { cmdKeymap = "<D-v>", leaderKeymap = "<leader>ps", modes = { "n", "v" }, description = "Paste from clipboard" },
  -- buffer/Window closing.
  { cmdKeymap = "<D-w>", leaderKeymap = "<leader>bd", modes = { "n", "v" }, description = "Close buffer" },
  { cmdKeymap = "<D-w>", leaderKeymap = "<C-/>", modes = { "t" }, description = "Close floating terminal" },
  { cmdKeymap = "<D-W>", leaderKeymap = "<leader>wd", modes = { "n", "v" }, description = "Close window" },
  -- Splitting
  {
    cmdKeymap = "<D-x>",
    leaderKeymap = "<leader>-",
    modes = { "n", "v" },
    description = "Split horizontally",
    back_to_insert = true,
  },
  {
    cmdKeymap = "<D-X>",
    leaderKeymap = "<leader>|",
    modes = { "n", "v" },
    description = "Split vertically",
    back_to_insert = true,
  },
  {
    cmdKeymap = "<D-y>",
    leaderKeymap = "<leader>yy",
    modes = { "n", "v" },
    description = "Yanky short cut",
    back_to_insert = false,
  },
  -- Zoxide navigation.
  { cmdKeymap = "<D-z>", leaderKeymap = "<leader>zz", modes = { "n", "v" }, description = "Navigate Cd with Zeoxide" },
  -- Searching
  { cmdKeymap = "<D-/>", leaderKeymap = "<leader>/", modes = { "n", "v" }, description = "Search (Global)" },
  {
    cmdKeymap = "<D-CR>",
    leaderKeymap = "<leader><CR>",
    modes = { "n", "v" },
    description = "@Conform.format()",
    back_to_insert = true,
  },
}

-- TODO: Make mappings from the list.
for _, mapping in ipairs(cmd_mappings) do
  -- Some keymap could be used in insert mode. Longer keymap like <leader>xx could not be supporting insert mode, but from D-* it could work.
  -- So wrap and call them here.
  local keymap = mapping.leaderKeymap:gsub("<leader>", " ")
  local modes = mapping.modes
  if not mapping.no_insert_mode then
    -- Make wrapped keymap in normal mode.
    vim.keymap.set("i", mapping.cmdKeymap, function()
      local refined_keymap
      if mapping.back_to_insert then
        refined_keymap = vim.api.nvim_replace_termcodes("<Esc>" .. keymap .. "i", true, false, true)
      else
        refined_keymap = vim.api.nvim_replace_termcodes("<Esc>" .. keymap, true, false, true)
      end
      vim.api.nvim_feedkeys(refined_keymap, "m", false)
    end, { desc = mapping.description })
  end
  vim.keymap.set(modes, mapping.cmdKeymap, function()
    local refined_keymap = vim.api.nvim_replace_termcodes(keymap, true, false, true)
    vim.api.nvim_feedkeys(refined_keymap, "m", false)
  end, { desc = mapping.description })
end
