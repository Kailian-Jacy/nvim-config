-- Tabline implementation extracted from options.lua

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

    if tab_id == vim.fn.tabpagenr() then
      tabline = tabline .. "%#TabLineSel#"
    else
      tabline = tabline .. "%#TabLine#"
    end

    tabline = tabline .. "%" .. tab_id .. "T"
    tabline = tabline .. " " .. (tab_prefix .. tab_name) .. " "
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

  return TablineString(tabs)
end

vim.go.tabline = "%!v:lua.Tabline()"
