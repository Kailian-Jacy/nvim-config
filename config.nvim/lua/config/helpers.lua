-- Helper functions extracted from options.lua

vim.g.find_launch_json = function(start_dir)
  local current_dir = start_dir
  while current_dir ~= "/" and current_dir ~= "" do
    local vscode_dir = current_dir .. "/.vscode"
    local launch_json = vscode_dir .. "/launch.json"

    if vim.fn.filereadable(launch_json) == 1 then
      return launch_json, vscode_dir
    end

    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end
  return nil, nil
end

---@param path string
---@param echo_name boolean
---@param record_zoxide boolean
---@return integer tabnr
vim.g.new_tab_at = function(path, echo_name, record_zoxide)
  vim.cmd [[ tabnew ]]
  path = vim.fn.fnamemodify(path, ':p')
  if vim.fn.isdirectory(path) == 1 then
    vim.cmd.tcd(path)
    if record_zoxide then
      vim.cmd('silent !zoxide add "' .. path .. '"')
    end
    if echo_name then
      vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
    end
  else
    vim.cmd("e " .. path)
  end
  return vim.fn.tabpagenr()
end


vim.g.is_current_window_floating = function()
  return vim.api.nvim_win_get_config(0).relative ~= ""
end

vim.g.is_plugin_loaded = function(plugin_name)
  return vim.tbl_get(require("lazy.core.config"), "plugins", plugin_name, "_", "loaded") ~= nil
end

vim.g.get_full_path_of = function(debugger_exe_name)
  local exe_path = vim.fn.trim(vim.fn.system("which " .. debugger_exe_name))

  if exe_path == "" then
    vim.notify(
      debugger_exe_name .. " is not installed. Please install it to use the debugger.",
      vim.log.levels.ERROR
    )
    return ""
  else
    return exe_path
  end
end

vim.g.function_get_selected_content = function()
  local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return table.concat(vim.fn.getregion(vstart, vend), "\n")
end

vim.g.is_in_visual_mode = function ()
  local current_mode = vim.fn.mode()
  return current_mode == 'v' or current_mode == 'V' or current_mode == '\22'
end

vim.g.get_word_under_cursor = function()
  return vim.fn.expand("<cword>")
end

-- Resource detection helpers
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
  if vim.fn.has("mac") == 1 then
    return "MACOS"
  elseif vim.fn.has("win32") == 1 then
    return "WINDOWS"
  elseif vim.fn.has("linux") == 1 then
    return "LINUX"
  end
  return "UNKNOWN"
end

-- Export resource detection results
vim.g._resource_executable_sqlite = vim.fn.executable("sqlite3")
vim.g._resource_cpu_cores = get_cpu_cores()
---@type OS_TYPE
vim.g._env_os_type = get_os_type()

-- Tmux helper
--- A helper function that returns the attached tmux client pids.
--- @return table<string>
vim.g.__tmux_get_current_attached_client_pid = function()
  local result = vim.fn.system(
    "pstree -p " .. vim.fn.getpid() .. " | grep tmux | grep client | sed -E 's/.*[ |(]([0-9]+)[ |)].*/\\1/' "
  )
  local tmux_client_pids = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(tmux_client_pids, line)
  end
  return tmux_client_pids
end

-- Obsidian helper
local function obsidian_app_exists()
  if vim.fn.has("mac") == 1 then
    if vim.fn.isdirectory(vim.g.obsidian_executable) == 1 then
      return true
    end
  end
  return false
end

-- Export for use in options.lua
return {
  get_os_type = get_os_type,
  get_cpu_cores = get_cpu_cores,
  obsidian_app_exists = obsidian_app_exists,
}
