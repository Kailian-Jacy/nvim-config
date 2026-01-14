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
-- vim.keymap.set({ "n", "v" }, "D", '"*d') -- Deprecated to enable "D": delete until the end of line.
vim.keymap.set({ "n", "v" }, "Y", '"*y')

-- Command mode keymaps:
vim.keymap.set("c", "<c-e>", "<end>", { desc = "move cursor to the end" })
vim.keymap.set("c", "<c-a>", "<home>", { desc = "move cursor to the end" })

-- Keymap for LuaPrint
vim.keymap.set("v", "<leader>pr", "<cmd>'<,'>LuaPrint<cr>", { desc = "Lua print" })

-- Path/Line fetching keymap.
vim.keymap.set({ "v", "n", "x" }, "<leader>yd", "<cmd>CopyFilePath dir<cr>", { desc = "Copy working directory path" })
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

-- Interrupt code runner 
vim.keymap.set({ "i", "n" }, "<C-c>", function()
  local uv = vim.uv or vim.loop
  if vim.g._current_runner then
    uv.kill(vim.g._current_runner, 9)
    vim.g._current_runner = nil
    vim.notify("runner cancelled.")
    return
  end
  -- Fallback to insert as normal.
  vim.api.nvim_feedkeys("<C-c>", "t", false)
end, { desc = "interrup running scripts" })

vim.keymap.set({ "n", "v" }, "<c-s-cr>", "<cmd>RunScript<CR>", { desc = "run current script" })
vim.keymap.set({ "n", "v" }, "<d-s-cr>", "<cmd>RunScript<CR>", { desc = "run current script" })

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

---@param direction "j"|"k"|"h"|"l" The direction to move the cursor
---@param move_around function The callback to be executed after check.
local move_around_checker = function(direction, move_around)
  return function()
    -- Check if it's the terminal buffer and decide available direction.
    local available_directions = {"j", "k", "h", "l"}
    -- If terminal that is set to be floating and full-screen.
    if vim.g.is_current_window_floating() then
      -- Prohibit moving. Do not allow shift.
      available_directions = {}
    end
    if not vim.tbl_contains(available_directions, direction) then
      -- ring bell.
      io.write("\a")
      return
    end
    -- Execute directions shift.
    move_around(direction)
  end
end

---@param direction "j"|"k"|"h"|"l" The direction to move the cursor
local cmd_win_move = function (direction)
  vim.cmd("wincmd " .. direction)
end

---@param direction "j"|"k"|"h"|"l" The direction to move the cursor
local keymap_win_move_terminal = function(direction)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-\\><c-n><c-w>" .. direction, true, false, true), "n", false)
end

vim.keymap.set({ "n", "v", "i" }, "<C-J>", move_around_checker("j", cmd_win_move), { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-H>", move_around_checker("h", cmd_win_move), { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-L>", move_around_checker("l", cmd_win_move), { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-K>", move_around_checker("k", cmd_win_move), { noremap = true, silent = true })
-- vim.keymap.set({ "n", "v", "i" }, "<C-BS>", "<cmd>wincmd p<cr>", { noremap = true, silent = true }) -- it won't go across tabs. useless.
vim.keymap.set({ "t" }, "<C-L>", move_around_checker("l", keymap_win_move_terminal), { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-H>", move_around_checker("h", keymap_win_move_terminal), { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-J>", move_around_checker("j", keymap_win_move_terminal), { noremap = true, silent = true })
vim.keymap.set({ "t" }, "<C-K>", move_around_checker("k", keymap_win_move_terminal), { noremap = true, silent = true })

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

-- Line shift.
vim.keymap.set({ "n", "v", "i" }, "<M-j>", function()
  local count = vim.fn.max({ vim.v.count, 1 })
  if vim.g.is_in_visual_mode() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", false)
    vim.cmd("'<,'>" .. "m '>+" .. count)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gv", true, false, true), "x", false)
  else
    vim.cmd("m +" .. count)
  end
end, { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<M-k>", function()
  local count = vim.fn.max({ vim.v.count, 1 })
  if vim.g.is_in_visual_mode() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", false)
    vim.cmd("'<,'>" .. "m '<-" .. 1 + count)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gv", true, false, true), "x", false)
  else
    vim.cmd("m -" .. 1 + count)
  end
end, { noremap = true, silent = true })

-- Visual till brackets.
-- TODO: conflict with auto-surrounding in visual mode.
-- { -> next  } -> prev.
-- should be usable in visual mode.
-- Temporarily disable this.
--
-- local till_signs = { "[", "]", "{", "}", "(", ")", ",", "<", ">", "?" }
-- for _, sign in ipairs(till_signs) do
--   vim.keymap.set({ "n" }, sign, "t" .. sign, { noremap = true })
--   -- vim.keymap.set({ "n", "v" }, sign, "t" .. sign, { noremap = true })
--   vim.keymap.set({ "n" }, "d" .. sign, "dt" .. sign, { noremap = true })
-- end

-- Tab-related.
vim.keymap.set("n", "<leader><tab>", "<cmd>tabnew<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab>", "<cmd>FlipPinnedTab<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "d<tab>", "<cmd>tabclose<CR>", { noremap = true, silent = true })

-- Migrate to normal-tabbing switching.
vim.keymap.set({ "n", "v", "i" }, "<C-tab>", "<cmd>tabnext<CR>", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<S-C-tab>", "<cmd>tabprev<CR>", { noremap = true, silent = true })
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

-- Neovide transparency control
vim.keymap.set("n", "<leader>uT", "<cmd>NeovideTransparentToggle<cr>", { noremap = true, silent = true })

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

-- Debugging related keymaps.
---@class DebuggingKeymapItem
---@field normalModeKey string
---@field debugModeKey string
---@field action string | function
---@field desc string
---@field visual_model boolean | nil @default false

---@alias DebuggingKeymaps DebuggingKeymapItem[]

---@type DebuggingKeymaps
local debugging_keymaps = {
  -- ['r'] = { f = require('go.dap').run, desc = 'run' },
  -- ["<D-b>"] = { f = widgets.centered_float(widgets.break), desc = "Widget: Variable in Scopes" },
  -- ["<D-r>"] = { f = require("dap").repl.toggle, desc = "repl toggle" },
  {
    normalModeKey = "<leader>db",
    debugModeKey = "b",
    action = function()
      require("dap").toggle_breakpoint()
    end,
    desc = "Toggle breakpoint"
  },
  {
    normalModeKey = "<leader>dB",
    debugModeKey = "B",
    action = function()
      require("dap-view").open()
      require("dap-view").jump_to_view("breakpoints")
    end,
    desc = "Show list of breakpoint"
  },
  {
    normalModeKey = "<leader>dc",
    debugModeKey = "c",
    action = function()
      require("dap").continue()
    end,
    desc = "Continue"
  },
  {
    normalModeKey = "<leader>dC",
    debugModeKey = "C",
    action = function()
      require("dap").run_to_cursor()
    end,
    desc = "Run to cursor"
  },
  {
    normalModeKey = "<leader>dW",
    debugModeKey = "W",
    action = function()
      local placeholder = vim.fn.expand("<cword>")
      if vim.fn.mode() == "v" then
        placeholder = vim.g.function_get_selected_content()
      end
      vim.api.nvim_feedkeys(":DapViewWatch " .. placeholder, "n", false) -- No CR to allow further edition.
    end,
    desc = "Add watch point",
    visual_model = true
  },
  {
    normalModeKey = "<leader>dn",
    debugModeKey = "n",
    action = function()
      require("dap").step_over()
    end,
    desc = "Step over"
  },
  {
    normalModeKey = "<leader>dN",
    debugModeKey = "N",
    action = function()
      vim.cmd("DapNew")
    end,
    desc = "Run new debug session"
  },
  {
    normalModeKey = "<leader>ds",
    debugModeKey = "s",
    action = function()
      require("dap").step_into()
    end,
    desc = "Step into"
  },
  {
    normalModeKey = "<leader>dS",
    debugModeKey = "S",
    action = function()
      require("dap-view").open()
      require("dap-view").jump_to_view("sessions")
    end,
    desc = "Show Sessions"
  },
  {
    normalModeKey = "<leader>do",
    debugModeKey = "o",
    action = function()
      require("dap").step_out()
    end,
    desc = "Step out"
  },
  {
    normalModeKey = "<leader>du",
    debugModeKey = "u",
    action = function()
      require("dap").up()
    end,
    desc = "Up"
  },
  {
    normalModeKey = "<leader>dd",
    debugModeKey = "d",
    action = function()
      require("dap").down()
    end,
    desc = "Down"
  },
  {
    normalModeKey = "<leader>dF",
    debugModeKey = "F",
    action = function()
      -- local widgets = require("dap.ui.widgets")
      -- widgets.centered_float(widgets.frames)
      require("dap-view").open()
      require("dap-view").jump_to_view("threads")
    end,
    desc = "Show frames"
  },
  {
    normalModeKey = "<leader>dp",
    debugModeKey = "p",
    action = function()
      require("dap.ui.widgets").hover()
    end,
    desc = "Hover"
  },
  {
    normalModeKey = "<leader>dP",
    debugModeKey = "P",
    action = function()
      require("dap-view").open()
      require("dap-view").jump_to_view("scopes")
    end,
    desc = "Preview the content in separate buffer"
    -- action = function()
    --   require("dap.ui.widgets").preview()
    -- end,
    -- desc = "Preview the content in separate buffer"
  },
  {
    normalModeKey = "<leader>dR",
    debugModeKey = "R",
    action = function()
      require("dap").restart()
    end,
    desc = "Terminate session"
  },
  {
    normalModeKey = "<leader>d<c-c>",
    debugModeKey = "<c-c>",
    action = function()
      require("dap").pause()
    end,
    desc = "Pause"
  },
  {
    normalModeKey = "<leader>dT",
    debugModeKey = "T",
    action = function()
      vim.cmd("DapViewToggle")
    end,
    desc = "Toggle DapView"
  },
  {
    normalModeKey = "<leader><D-BS>",
    debugModeKey = "<D-BS>",
    action = function()
      -- go back to line in the current frame.
      -- could be adjusted with `vim.o.switchbuf`
      require("dap").focus_frame()
    end,
    desc = "Terminate session"
  },
  {
    normalModeKey = "<leader>dE",
    debugModeKey = "E",
    action = function()
      require("dap").disconnect()
      require("dap").close()
    end,
    desc = "Stop session"
  },
}

-- Set normal mode keymaps.
for _, item in ipairs(debugging_keymaps) do
  ---@type string | string[]
  local mode = "n"
  if item.visual_model then
    mode = { "n", "v" }
  end
  vim.keymap.set(mode, item.normalModeKey, item.action, { noremap = true, silent = true })
end

vim.g.nvim_dap_keymap = function()
  -- Prevent keymapping set during keymap.
  if vim.g.nvim_dap_noui_backup_keymap ~= nil then
    vim.print_silent("Already in debugging keymap.")
    return
  end

  vim.g.nvim_dap_noui_backup_keymap = vim.api.nvim_get_keymap("n")

  for _, item in ipairs(debugging_keymaps) do
    ---@type string | string[]
    local mode = "n"
    if item.visual_model then
      mode = { "n", "v" }
    end
    -- local mode, keymap = key:match("([^|]*)|?(.*)")
    local keymap = item.debugModeKey
    -- if type(item) == "string" then
    --   item = rhs_options.map_cr(item):with_noremap():with_silent()
    -- end
    if type(item) == "table" and item.action then
      vim.keymap.set(mode, keymap, item.action)
    end
  end
end

vim.g.nvim_dap_upmap = function()
  if vim.g.nvim_dap_noui_backup_keymap == nil then
    vim.print_silent("Already left debugging keymap.")
    return
  end

  for _, item in ipairs(debugging_keymaps) do
    vim.cmd("silent! unmap " .. item.debugModeKey)
  end

  vim.cmd([[silent! vunmap p]])

  for _, item in ipairs(debugging_keymaps) do
    local k = item.debugModeKey
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
    no_insert_mode = true,
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
