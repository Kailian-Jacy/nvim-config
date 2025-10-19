-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua


-- Helper functions.
vim.g.is_current_window_floating = function ()
  return vim.api.nvim_win_get_config(0).relative ~= ""
end

vim.g.get_full_path_of = function(debugger_exe_name)
  local exe_path = vim.fn.trim(vim.fn.system("which " .. debugger_exe_name))

  -- Check if codelldb is found
  if exe_path == "" then
    -- If not found, show a notification and panic
    vim.notify(
      debugger_exe_name .. " is not installed. Please install it to use the debugger.",
      vim.log.levels.ERROR
    )
    return ""
  else
    -- Return the absolute path of codelldb
    -- vim.notify(debugger_exe_name .. " loaded.")
    return exe_path
  end
end

-- Customized Tabs
---@class PinnedTab
---@field id integer
---@field name string
---@field buffers table<integer>

---@type PinnedTab?
vim.g.pinned_tab = nil

vim.g.last_tab = nil
vim.g.pinned_tab_marker = "󰐃"

local get_tab_workdir = function(index)
  local win_num = vim.fn.tabpagewinnr(index)
  return vim.fn.getcwd(win_num, index)
end

vim.g.tabname = function(tab_id)
  -- Naming: priority: tabname var > general dedup mark > workdir path name.
  local name = ""

  local tabname = vim.fn.gettabvar(tab_id, "tabname", "")
  if tabname == vim.NIL then
    tabname = ""
  end
  tabname = tostring(tabname)

  if tabname ~= "" then
    name = tabname
  end

  if name == "" and vim.g.tab_path_mark then
    -- Take the tab workdir, match against the settings.
    local working_directory = get_tab_workdir(tab_id)
    for pattern, predefined_name in pairs(vim.g.tab_path_mark) do
      if string.match(working_directory, pattern) then
        name = "[" .. predefined_name .. "]" .. vim.fn.fnamemodify(working_directory, ":t")
        break
      end
    end
  end

  if name == "" then
    local working_directory = get_tab_workdir(tab_id)
    name = vim.fn.fnamemodify(working_directory, ":t")
  end
  return name
end

-- Helper functions and resource detection.
local _if_not_set_or_true = function(var)
  return var == nil or var == true
end
local function get_cpu_cores()
  local handle = io.popen("nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1")
  if not handle then
    return 1
  end
  local result = handle:read("*n") or 1
  handle:close()
  return result
end

---@alias OS_TYPE  "UNKNOWN" | "MACOS" | "WINDOWS" | "LINUX"
---@return OS_TYPE
local function get_os_type()
  if vim.fn.has("mac") then
    return "MACOS"
  elseif vim.fn.has("win32") then
    return "WINDOWS"
  elseif vim.fn.has("linux") then
    return "LINUX"
  end
  return "UNKNOWN"
end

-- Being used by storages like bookmarks and yanky. Sometimes fallback to shada.
vim.g._resource_executable_sqlite = vim.fn.executable("sqlite3")
vim.g._resource_cpu_cores = get_cpu_cores()
---@type OS_TYPE
vim.g._env_os_type = get_os_type()

---@class ModuleConfig
---@field enabled boolean

-- Optional Features
--------------------------------------------------
-- If reading binary with xxd and show as human-readable text.
--
-- Disabled for now. Generally, reading binary in vim does not make any sense.
-- Loading and converting the binary is very heavy work for vim.
-- I'll leave an option here to allow enabling it when needed.
vim.g.read_binary_with_xxd = false

-- Modules enabling setup. Modules variables could be overriden by local.lua
---@type table<ModuleConfig>
local default_modules_config = {
  rust = {
    enabled = vim.fn.executable("rustc"),
  },
  go = {
    enabled = vim.fn.executable("go"),
  },
  python = {
    enabled = vim.fn.executable("python") or vim.fn.executable("python3"),
  },
  cpp = {
    enabled = vim.fn.executable("gcc"),
  },
  --- Plugin feature support. Detect dependencies and enable feature. ---

  copilot = {
    enabled = vim.fn.executable("node"),
  },
  bookmarks = {
    enabled = vim.g._resource_executable_sqlite,
  },
  svn = {
    enabled = vim.fn.executable("svn"),
  },
}

vim.g.modules = vim.tbl_deep_extend("keep", (vim.g.modules or {}), default_modules_config)

--------------------------------------------------

-- Terminal
vim.g.terminal_width_right = 0.3
vim.g.terminal_width_left = 0.3
vim.g.terminal_width_bottom = 0.3
vim.g.terminal_width_top = 0.3
vim.g.terminal_auto_insert = true
vim.g.terminal_default_tmux_session_name = "nvim-attached"

-- Tmux

--- A helper function that returns the attached tmux client pids. It's a table since there could be multiple sessions attached.
--- @return table<string>
vim.g.__tmux_get_current_attached_cliend_pid = function()
  local result = vim.fn.system(
    "pstree -p " .. vim.fn.getpid() .. " | grep tmux | grep client | sed -E 's/.*[ |(]([0-9]+)[ |)].*/\\1/' "
  )
  local tmux_client_pids = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(tmux_client_pids, line)
  end
  -- TODO: under linux, grep -z "^TMUX" /tmp/pidOfTmux/environ
  -- returns a path to the tmux session socket. which can be used to control the very client.
  -- But found no way to get the path (/private/tmp/tmux-501/default) under macos. Seems like private to each process.
  return tmux_client_pids
end

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- UI related.
vim.cmd([[ set laststatus=3 ]]) -- Global lualine across each windows.
vim.cmd([[ set signcolumn=yes:1 ]]) -- Constant status column indentation.
vim.cmd([[ set cmdheight=0 noshowmode noruler noshowcmd ]])

-- Font. Now we are setting font in neovide configuration to keep consistency.
-- vim.o.guifont = 'MonoLisa Nerd Font Light:h14'

-- Highlighting Source.
vim.cmd([[ syntax off ]]) -- we won't need syntax anytime. It seems to conflict with pickers. Use treesitter at least.
vim.g.use_treesitter_highlight = { "c", "cpp" } -- Some LSP provides poor semantic highlights. Currently treesitter based solution is a beneficial compliment.

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
-- Use lua snip like `lua vim.fn.settabvar(vim.fn.tabpagenr(), "tabname", "example tabname")` to set tabname.

---@class TabDescriptions
---@field index integer
---@field name? string
---@field prefix? string

---@param tab_descriptions table<TabDescriptions>
function TablineString(tab_descriptions)
  local tabline = ""
  for index = 1, #tab_descriptions do
    local tab_descriptor = tab_descriptions[index]
    local tab_id, tab_name, tab_prefix = tab_descriptor.index, tab_descriptor.name, (tab_descriptor.prefix or "")

    -- Select highlighting based on active tab
    if tab_id == vim.fn.tabpagenr() then
      tabline = tabline .. "%#TabLineSel#" -- Highlight selected tab
    else
      tabline = tabline .. "%#TabLine#" -- Highlight inactive tabs
    end

    -- Set tab page number for mouse clicks
    tabline = tabline .. "%" .. tab_id .. "T"
    tabline = tabline .. " " .. (tab_prefix .. tab_name) .. " "

    -- Add a fill character and close button (optional)
    -- tabline = tabline .. "%#TabLineFill#" .. "%X"
  end
  return tabline
end

function Tabline()
  ---@type table<TabDescriptions>
  local tabs = {}
  ---@type TabDescriptions?
  local pinned_tab = nil

  for index = 1, vim.fn.tabpagenr("$") do
    local name = vim.g.tabname(index)

    -- Put the pinned tab at the very beginning
    tabs[#tabs + 1] = {
      index = index,
      name = name,
      prefix = "",
    }

    if index == 1 and vim.g.pinned_tab then
      tabs[#tabs].prefix = vim.g.pinned_tab_marker .. " "
    end
  end

  if pinned_tab then
    table.insert(tabs, 1, pinned_tab)
  end

  -- Predispose: set the name for those working directory matching given style
  -- Return tabline string.
  return TablineString(tabs)
end
vim.go.tabline = "%!v:lua.Tabline()"

vim.g.function_get_selected_content = function()
  local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return table.concat(vim.fn.getregion(vstart, vend), "\n")
end

vim.g.get_word_under_cursor = function()
  return vim.fn.expand("<cword>")
end

vim.opt.fillchars = "diff:╱,eob:~,fold: ,foldclose:,foldopen:,foldsep: "
--[[Running = "Running",
  Stopped = "Stopped",
  DebugOthers = "DebugOthers",
  NoDebug = "NoDebug"]]
vim.g.debugging_status = "NoDebug"
vim.g.recording_status = false
vim.g.debugging_keymap = false

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
vim.g.neovide_input_use_logo = 1

-- Global tabstop.
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 0
vim.opt.expandtab = true

-- copilot endpoint
-- vim.g.copilot_auth_provider_url = "https://copilot.aizahuo.com"

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
vim.g.yanky_ring_max_accept_length = 1000

-- Snippet path settings
vim.g.import_user_snippets = true
vim.g.user_vscode_snippets_path = {
  vim.fn.stdpath("config") .. "/snip/", -- How to get: https://arc.net/l/quote/fjclcvra
}
if vim.g._env_os_type == "MACOS" then
  vim.g.user_vscode_snippets_path[#vim.g.user_vscode_snippets_path + 1] =
    vim.fn.expand("$HOME/Library/Application Support/Code/User/snippets/") -- Default Vscode snippet path under MacOS.
end

-- vim.g.user_vscode_snippets_path = "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" -- How to get: https://arc.net/l/quote/fjclcvra
-- Linking: ln -s "/Users/kailianjacy/Library/Application Support/Code/User/snippets/" /Users/kailianjacy/.config/nvim/snip.

-- Add any additional options here
vim.g.autoformat = false
-- restrict: Apply restricted format: in normal mode, only format the minimum text object; in visual mode, format selected region.
-- select_only: Only format under selected mode.
---@enum "all" | "restrict" | "select_only"
vim.g.do_not_format_all = "restrict" 

-- Theme setting
-- vim.opt.statuscolumn = "%=%{v:relnum?v:relnum:v:lnum} %s"
