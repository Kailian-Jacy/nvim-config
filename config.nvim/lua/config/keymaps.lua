-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

vim.g.mapleader = " "

-- Lsp replace name.
vim.keymap.set("n", "<leader>rn", ":IncRename ")
vim.keymap.set({"n", "i", "v"}, "<c-i>", "<c-i>")

-- Keymap Line
vim.keymap.set("n", "ZA", function ()
  vim.cmd [[ wqa ]]
end , { noremap = true })
-- as exiting vim with running jobs seems dangerous, I choose to use :qa! to explicitly do so.

-- Git related
vim.keymap.set("n", "<leader>G", "<cmd>LazyGit<CR>", {noremap = true, silent = true})

-- message history display
--vim.keymap.set({ "n", "v" }, "<leader>snh", function()
--  vim.cmd([[ new ]])
--  vim.cmd([[ resize ]] .. math.floor(vim.o.lines * 0.3))
--  vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>bdelete!<CR>", { noremap = true, silent = true })
--  vim.cmd([[put =execute('messages')]])
--end)

-- Cursor wandering around
vim.keymap.set({ "n", "v", "i" }, "<C-j>", "<C-W>j", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-h>", "<C-W>h", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-l>", "<C-W>l", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "i" }, "<C-k>", "<C-W>k", { noremap = true, silent = true })

-- search
vim.keymap.set("v", "/", '"fy/\\V<C-R>f<CR>')
vim.keymap.set("n", "<leader>/", require("telescope").extensions.live_grep_args.live_grep_args, { noremap = true })
vim.keymap.set(
  "v",
  "<leader>/",
  require("telescope-live-grep-args.shortcuts").grep_visual_selection,
  { noremap = true }
)
-- nnoremap <leader>/ <cmd>Telescope live_grep<cr>
-- vnoremap <leader>/ "zy:Telescope live_grep default_text=<C-r>z<cr>
vim.keymap.set("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "ge", "<cmd>lua vim.diagnostic.open_float()<CR>", { noremap = true, silent = true })

-- disable lazyim default keymaps.
vim.keymap.del("n", "<leader>l")
vim.keymap.del("n", "<leader>L")

-- copilot mapping: copilot mapping are all migrated to the configuration part of nvim-cmp.
vim.g.copilot_no_maps = true

-- telescope based:
vim.keymap.set("n", "<leader>tt", "<cmd>Telescope resume<CR>", { noremap = true, silent = true })

-- buffer related
vim.keymap.set("n", "<leader>bd", function()
  if #vim.fn.getbufinfo({ bufloaded = true }) == 1 and #vim.api.nvim_list_tabpages() == 1 then
    vim.notify("last buf", vim.log.levels.INFO)
  elseif #vim.fn.getbufinfo({ bufloaded = true }) == 1 then
    vim.cmd("tabclose")
  else
    vim.cmd("bdelete")
  end
end, { noremap = true, silent = true })

-- Tab-related.
vim.keymap.set("n", "<leader><tab>", "<cmd>Telescope telescope-tabs list_tabs<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>ft", "<cmd>Telescope telescope-tabs list_tabs<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab>n", "<cmd>tabnew<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab><tab>", "<cmd>tabnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-tab><S-tab>", "<cmd>tabprevious<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab>l", "<cmd>tabnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<tab>h", "<cmd>tabprevious<CR>", { noremap = true, silent = true })

-- conform formatting
function TriggerFormatForCurrentBuf()
  require("conform").format()
  vim.print("@conform.format")
end
vim.keymap.set("n", "<leader><Enter>", TriggerFormatForCurrentBuf, { noremap = true, silent = true })

-- context display
vim.keymap.set({ "n", "i", "x" }, "<C-G>", function()
  vim.print(require("nvim-navic").get_location())
end)

-- Mapping and unmapping during debugging.
vim.g.nvim_dap_noui_backup_keymap = {}

local rhs_options = {}
function rhs_options:map_cr(cmd_string)
  self.cmd = (":%s<CR>"):format(cmd_string)
  return self
end

NoUIKeyMap = function()
  vim.g.nvim_dap_noui_backup_keymap = vim.api.nvim_get_keymap("n")
  local keys = {
    -- DAP --
    -- run
    -- ['r'] = { f = require('go.dap').run, desc = 'run' },
    ["c"] = { f = require("dap").continue, desc = "continue" },
    ["n"] = { f = require("dap").step_over, desc = "step_over" },
    ["s"] = { f = require("dap").step_into, desc = "step_into" },
    ["o"] = { f = require("dap").step_out, desc = "step_out" },
    ["S"] = { f = require("dap").terminate, desc = "stop debug session" },
    ["u"] = { f = require("dap").up, desc = "up" },
    ["D"] = { f = require("dap").down, desc = "down" },
    ["C"] = { f = require("dap").run_to_cursor, desc = "run_to_cursor" },
    ["b"] = { f = require("dap").toggle_breakpoint, desc = "toggle_breakpoint" },
    ["P"] = { f = require("dap").pause, desc = "pause" },
    ["p"] = { f = require("dap.ui.widgets").hover, m = { "n", "v" }, desc = "hover" },
  }
  for key, value in pairs(keys) do
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

NoUIUnmap = function()
  --[[if not _GO_NVIM_CFG.dap_debug_keymap then
  return
  end]]
  local unmap_keys = {
    -- 'r',
    "c",
    "n",
    "s",
    "o",
    "S",
    "u",
    "D",
    "C",
    "b",
    "P",
    'p',
  --[['K',
  'B',
  'R',
  'O',
  'a',
  'w',]]
  }
  for _, value in pairs(unmap_keys) do
    local cmd = "silent! unmap " .. value
    vim.cmd(cmd)
  end

  vim.cmd([[silent! vunmap p]])

  for _, k in pairs(unmap_keys) do
    for _, v in pairs(vim.g.nvim_dap_noui_backup_keymap or {}) do
      if v.lhs == k then
        local nr = (v.noremap == 1)
        local sl = (v.slient == 1)
        local exp = (v.expr == 1)
        local mode = v.mode
        local desc = v.desc or "go-dap"
        if v.mode == " " then
          mode = { "n", "v" }
        end

        vim.keymap.set(mode, v.lhs, v.rhs or v.callback, { noremap = nr, silent = sl, expr = exp, desc = desc })
        -- vim.api.nvim_set_keymap('n', v.lhs, v.rhs, {noremap=nr, silent=sl, expr=exp})
      end
    end
  end
  vim.g.nvim_dap_noui_backup_keymap = {}
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
NoUIGeneircDebug = function()
  -- Invoke debugging. dap.ext.vscode.launch_js reads the launch debug file;
  -- Choose debug file for debugging.
  -- Set Keymap for debugging
  if isInDebugging() then
    vim.print("Session is already activated.")
  end
  -- (Re-)reads launch.json if present
  if vim.fn.filereadable(".vscode/launch.json") then
    require("dap.ext.vscode").load_launchjs(nil, {
      debugpy = { "python" },
      cpptools = { "c", "cpp" },
    })
  end
  require("dap").continue()
end

vim.keymap.set("n", "<leader>DD", NoUIGeneircDebug)

--[[
vim.keymap.set("n", "<leader>sn", function()
  require("dap").step_over()
end)
vim.keymap.set("n", "<leader>si", function()
  require("dap").step_into()
end)
vim.keymap.set("n", "<leader>so", function()
  require("dap").step_out()
end)
vim.keymap.set("n", "<leader>C", function()
  require("dap").run_to_cursor()
end)
vim.keymap.set("n", "<leader>bb", function()
  require("dap").toggle_breakpoint()
end)
vim.keymap.set("n", "<Leader>bB", function()
  require("dap").set_breakpoint()
end)
vim.keymap.set("n", "<Leader>lp", function()
  require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end)
vim.keymap.set("n", "<Leader>dr", function()
  require("dap").repl.open()
end)
vim.keymap.set("n", "<Leader>dl", function()
  require("dap").run_last()
end)
vim.keymap.set({ "n", "v" }, "gh", function()
  if isInDebugging() then
    vim.print("Session is already activated.")
  else
    vim.lsp.buf.hover()
  end
  require("dap.ui.widgets").hover()
end)
vim.keymap.set({ "n", "v" }, "<Leader>dp", function()
  require("dap.ui.widgets").preview()
end)
vim.keymap.set("n", "<Leader>df", function()
  local widgets = require("dap.ui.widgets")
  widgets.centered_float(widgets.frames)
end)
vim.keymap.set("n", "<Leader>ds", function()
  local widgets = require("dap.ui.widgets")
  widgets.centered_float(widgets.scopes)
end)
]]
