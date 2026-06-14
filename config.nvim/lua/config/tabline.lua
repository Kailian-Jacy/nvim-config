-- Tabline implementation extracted from options.lua

-- Terminal bell indicator per tab
-- Maps tabpage handle → boolean (true = beeping, needs attention)
---@type table<integer, boolean>
vim.g._tab_beep = vim.g._tab_beep or {}

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
---@field suffix? string

---@param tab_descriptions table<TabDescriptions>
function TablineString(tab_descriptions)
  local tabline = ""
  for index = 1, #tab_descriptions do
    local tab_descriptor = tab_descriptions[index]
    local tab_id = tab_descriptor.index
    local tab_name = tab_descriptor.name
    local tab_prefix = tab_descriptor.prefix or ""
    local tab_suffix = tab_descriptor.suffix or ""

    if tab_id == vim.fn.tabpagenr() then
      tabline = tabline .. "%#TabLineSel#"
    else
      tabline = tabline .. "%#TabLine#"
    end

    tabline = tabline .. "%" .. tab_id .. "T"
    tabline = tabline .. " " .. (tab_prefix .. tab_name .. tab_suffix) .. " "
  end
  return tabline
end

function Tabline()
  ---@type table<TabDescriptions>
  local tabs = {}
  ---@type TabDescriptions?
  local pinned_tab = nil

  local beep_set = vim.g._tab_beep or {}
  for index = 1, vim.fn.tabpagenr("$") do
    local name = vim.g.tabname(index)
    local tabpage = vim.api.nvim_list_tabpages()[index]

    tabs[#tabs + 1] = {
      index = index,
      name = name,
      prefix = "",
      suffix = "",
    }

    if index == 1 and vim.g.pinned_tab then
      tabs[#tabs].prefix = vim.g.pinned_tab_marker .. " "
    end

    -- Show beep indicator for tabs with terminal bell
    if tabpage and beep_set[tostring(tabpage)] then
      tabs[#tabs].suffix = " ●"
    end
  end

  if pinned_tab then
    table.insert(tabs, 1, pinned_tab)
  end

  return TablineString(tabs)
end

vim.go.tabline = "%!v:lua.Tabline()"

-- Bell detection is handled by the floatterm proxy (see floatterm/init.lua M._on_term_bell).
-- The proxy intercepts \x07 in stdout and calls _on_term_bell which updates vim.g._tab_beep.

-- Clear beep indicator only when the local terminal buffer is focused again
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = vim.api.nvim_create_augroup("TablineTermBellClear", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "termlocal" then
      return
    end
    local current_tab = vim.api.nvim_get_current_tabpage()
    local beep_set = vim.g._tab_beep or {}
    if beep_set[tostring(current_tab)] then
      beep_set[tostring(current_tab)] = nil
      vim.g._tab_beep = beep_set
      vim.cmd("redrawtabline")
    end
  end,
})
