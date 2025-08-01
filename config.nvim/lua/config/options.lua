-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

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
vim.g.use_treesitter_highlight = true -- Some LSP provides poor semantic highlights. Currently treesitter based solution is a beneficial compliment.

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
function MyTabLine()
  local tabnames = {}
  local groups = {} -- { tabname = { { index1, split_path1 }, { index2, split_path2 } } }

  local function group_by(group, get_identifier)
    local ret = {}
    local group_cnt = 0
    for _, item in pairs(group) do
      local identifier = get_identifier(item)
      if identifier then
        if not ret[identifier] then
          ret[identifier] = {}
          group_cnt = group_cnt + 1
        end
        table.insert(ret[identifier], item)
      else
      end
    end
    return ret, group_cnt
  end

  local function format_tabname(uniq, tail)
    if #uniq > 0 then
      return uniq .. "." .. tail
    end
    return tail
  end

  local function split_path(path)
    local result = {}
    for str in string.gmatch(path:gsub("^/", ""):gsub("/$", ""), "([^/]+)") do
      table.insert(result, str)
    end
    return result
  end

  for index = 1, vim.fn.tabpagenr("$") do
    local win_num = vim.fn.tabpagewinnr(index)
    local working_directory = vim.fn.getcwd(win_num, index)
    local tabname = vim.fn.gettabvar(index, "tabname")
    if tabname == nil or tabname == "" then
      tabname = vim.fn.fnamemodify(working_directory, ":t")
    end

    tabnames[index] = tabname
    if not groups[tabname] then
      groups[tabname] = {}
    end
    table.insert(groups[tabname], { index, split_path(vim.fn.fnamemodify(working_directory, ":p:h")) })
  end

  -- Diff in group to eliminate same tabnames.
  local round_cnt = 500 -- prevent deadloop.
  while round_cnt > 0 do
    -- Those who has uniq tabname gets rolled out.
    local non_zero_count = 0
    for tabname, body in pairs(groups) do
      if #body == 1 then
        groups[tabname] = nil
      else
        non_zero_count = non_zero_count + 1
      end
    end
    if non_zero_count == 0 then
      break
    end
    local new_groups = {}
    -- For each group that has multiple string sharing the same ending.
    for tabname, bodies in pairs(groups) do
      local min_section_count = 100000
      for _, index_and_sections in ipairs(bodies) do
        min_section_count = math.min(min_section_count, #index_and_sections[2])
      end
      for i = 1, min_section_count + 1 do
        local _group_by_sections, _group_cnt = group_by(bodies, function(item)
          if item[2][i] then
            return item[2][i] -- ith sections.
          else
            return "" -- for those has reached max length, use "" as special group
          end
        end)
        -- special dispose those "" group (poths that reaches the maximum length)
        if _group_by_sections[""] then
          for _, index_and_sections in ipairs(_group_by_sections) do
            tabnames[index_and_sections[1]] = format_tabname("", tabnames[index_and_sections[1]])
          end
          _group_by_sections[""] = nil
        end

        -- dispose remainder non-max groups.
        if _group_cnt ~= 1 then
          -- split the group.
          for section, section_bodies in pairs(_group_by_sections) do
            if #section_bodies == 1 then
              -- Uniq. Just modify the global.
              -- Debug unique tabname resolution
              tabnames[section_bodies[1][1]] = format_tabname(section, tabnames[section_bodies[1][1]])
            else
              -- needs to be split further. put to new_group.
              if not new_groups[tabname] then
                new_groups[tabname] = {}
              end
              for _, index_and_sections in ipairs(section_bodies) do
                -- trim compared ones.
                index_and_sections[2] = { unpack(index_and_sections[2], i) }
                table.insert(new_groups[tabname], index_and_sections)
              end
            end
          end
          goto next_tabname_round
        end
      end
      ::next_tabname_round::
    end
    groups = new_groups
    round_cnt = round_cnt - 1
  end
  -- vim.print(tabnames)
  local tabline = ""
  for index = 1, vim.fn.tabpagenr("$") do
    -- select the highlighting
    if index == vim.fn.tabpagenr() then
      tabline = tabline .. "%#TabLineSel#"
    else
      tabline = tabline .. "%#TabLine#"
    end

    -- set the tab page number (for mouse clicks)
    tabline = tabline .. "%" .. index .. "T"

    local win_num = vim.fn.tabpagewinnr(index)
    local working_directory = vim.fn.getcwd(win_num, index)
    local project_name = vim.fn.fnamemodify(working_directory, ":t")
    tabline = tabline .. " " .. tabnames[index] .. " "
  end

  -- after the last tab fill with TabLineFill and reset tab page nr
  tabline = tabline .. "%#TabLineFill#%T"
  return tabline
end
vim.go.tabline = "%!v:lua.MyTabLine()"

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
vim.g.copilot_auth_provider_url = "https://copilot.aizahuo.com"

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

-- Theme setting
-- vim.opt.statuscolumn = "%=%{v:relnum?v:relnum:v:lnum} %s"
