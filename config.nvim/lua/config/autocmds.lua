-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- TODO: git worktree automation.
-- TEST=script_runner; git worktree add ../neovim_test_$TEST
-- TEST=script_runner; ln -s $(pwd)/neovim_test_$TEST/config.nvim ~/.config/neovim_test_$TEST
--
-- Run tests:
-- TEST=script_runner; NVIM_APPNAME=neovim_test_$TEST nvim +"cd ~/.config/neovim_test_$TEST" +"RunTest"

-- Test runner
vim.api.nvim_create_user_command("RunTest", function()
  local cwd = vim.fn.getcwd()
  local test_files = vim.fn.globpath(cwd, "*_vimtest.lua", true, true)
  if #test_files == 0 then
    return
  end

  for _, file in ipairs(test_files) do
    vim.notify("---Testing file " .. file .. " ---", vim.log.levels.INFO)
    local success, result = pcall(dofile, file)
    if not success then
      vim.notify("---Error executing test file " .. file .. ": " .. result, vim.log.levels.ERROR)
    else
      if result ~= nil then
        vim.notify("---Test result: " .. tostring(result), vim.log.levels.INFO)
      end
    end
  end
end, { desc = "run *_vimtest.lua" })

-- Script runner.
-- Possibly turn it into a standalone plugin later.
vim.api.nvim_create_user_command("RunScript", function()
    local uv = vim.uv or vim.loop
    ---@class runner_definition
    ---@field runner (fun(): string) | string | nil
    ---@field template fun(runner: string, text: string) | string
    ---@field timeout number? single command timeout in sec

    ---@type table<string, runner_definition>
    local filetype_runner = {
      ["python"] = {
        runner = function()
          -- Use python: selected > python3 > python.
          local candidates = {
            require('venv-selector').get_active_path() or "",
            "python3",
            "python"
          }
          local found = false
          local python_intepreter = ""
          for _, candidate in ipairs(candidates) do
            if vim.fn.executable(candidate) ~= 0 then
              python_intepreter = candidate
              found = true
              break
            end
          end
          if not found or #python_intepreter == 0 then
            vim.notify("no usable python intepreter.", vim.log.levels.ERROR)
            return ""
          end
          return python_intepreter
        end,

        -- Content in template:
        -- 1. \r\n will be used as actual meaning (not escaped).
        -- 2. ${runner} and ${text} will be replaced.
        -- 3. Execute in current neovim shell cmd like ${shell} -c ${cmd}.
        template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
        timeout = 3,
      },
      ["nu"] = {
        runner = "nu",
        template = "COMMANDS=$(cat<<EOF\n${text}\nEOF\n);${runner} --commands $COMMANDS --no-newline",
        timeout = 5,
      },
      -- For lua, just run in the neovim instance. To run lua outside of the neovim, set runner as other lua interpreter.
      ["lua"] = {
        runner = "this_neovim",
        template = "${text}",
      },
      ["sh"] = {
        runner = "zsh",
        template = "${text}",
      }
    }

    local bufid = vim.api.nvim_get_current_buf()
    local winid = vim.api.nvim_get_current_win()

    -- Choose runner: buff local > predefined.
    -- TODO: Example runner oneliner: lua vim.b.runner = {  }
    local all_runners = vim.b["runner"] or {}
    if #vim.bo.filetype == 0 then
      vim.notify("No filetype detected.", vim.log.levels.ERROR)
      return
    end

    local runner = all_runners[vim.bo.filetype] or filetype_runner[vim.bo.filetype]
    if not runner then
      vim.notify("No runner found for filetype: " .. vim.bo.filetype, vim.log.levels.ERROR)
      return
    end

    -- Get text: selected > full text.
    local text_literal = ""
    if vim.g.is_in_visual_mode() then
      text_literal = vim.g.function_get_selected_content()
    else
      text_literal = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    end

  -- Register Runner.
  local runner_literal = ""
  if not runner.runner then
    -- possibly using runner hardcoded in template.
  elseif type(runner.runner) == "string" then
    runner_literal = runner.runner
  elseif type(runner.runner) == "function" then
    runner_literal = runner.runner()
    -- false or nil
    if not runner_literal then
      vim.notify("runner function returned abortion.", vim.log.level.INFO)
      return
    end
  else
    vim.notify("Runner template is not qualified", vim.log.levels.ERROR)
    return
  end
  assert(type(runner_literal) == "string")

  -- Register template.
  local template_literal = ""
  if type(runner.template) == "string" then
    template_literal = runner.template
  elseif type(runner.template) == "function" then
    template_literal = runner.template(runner_literal, text_literal)
    -- false or nil
    if not template_literal then
      vim.notify("template function returned abortion.", vim.log.level.INFO)
      return
    end
  else
    vim.notify("Runner template is not qualified", vim.log.levels.ERROR)
    return
  end
  assert(type(template_literal) == "string")

  -- Assemble command
  template_literal = string.gsub(template_literal, "${runner}", runner_literal)
  template_literal = string.gsub(template_literal, "${text}", text_literal)

  -- Register timeout. Default to be 3s.
  local timeout = 0
  local timeout_cancidates = {
    vim.g._runner_global_timeout or 0,
    runner.timeout or 0,
    filetype_runner[vim.bo.filetype].timeout or 0,
    3000
  }
  for _, candidate in ipairs(timeout_cancidates) do
    if candidate and type(candidate) == "number" or candidate > 0 then
      timeout = candidate
    end
  end

  -- As the runner is designed to be transient, we are just using global runner here.
  -- You can always use ctrl-C to stop it.
  if vim.bo.filetype == "lua" and runner_literal == "this_neovim" then
    local func = loadstring(template_literal) or function()
      vim.notify("neovim lua: failed to parse lua code block.", vim.log.levels.ERROR)
    end
    -- TODO: no timeout function for built-in types now.
    func()
  else
    vim.print(template_literal)
    local ok, job_or_err = pcall(
    -- vim.g._current_runner = vim.fn.jobstart(
      vim.system,
      {
        vim.o.shell,
        "-c",
        template_literal
      },
      {
        text = true,
      },
      -- Report result to cursor position or end of the document when runner ends.
      vim.schedule_wrap(function(obj)
        -- Replace the last command.
        -- If the last command is running, just kill it and remove.
        if vim.g._current_runner then
          uv.kill(vim.g._current_runner, 9)
          vim.notify("stopped another running script.", vim.log.levels.INFO)
        end
        vim.g._current_runner = nil
        vim.print(vim.inspect(obj))

        if obj.signal == 9 then
          return
        end

        local return_text = "\n"

        if #obj.stdout > 0 then
          return_text = return_text .. obj.stdout .. "\n"
        end

        if #obj.stderr > 0 then
          return_text = return_text .. obj.stderr .. "\n"
        end

        if #return_text == 0 then
          vim.notify("script_runner ends with nothing: " .. string(obj.code))
          return
        end
        return_text = string.gsub(return_text, "\n+$", "") .. "\n"

        -- Set the undo checkpoint for quick undo.
        -- reference: https://vi.stackexchange.com/questions/27185/break-the-undo-sequence-in-normal-mode
        vim.cmd [[ let &ul=&ul ]]

        -- Insert at the cursor position.
        local pos = {}
        if vim.api.nvim_get_current_buf() ~= bufid then
          vim.notify("script_runner finished in another buf.", vim.log.levels.INFO)
          pos = vim.api.nvim_buf_get_mark(bufid, '"')
        else
          pos = vim.api.nvim_win_get_cursor(winid)
        end
        vim.api.nvim_buf_set_lines(bufid, pos[1], pos[1], false, vim.split(return_text, "\n"))
      end)
    )

    if not ok then
      vim.notify(string.format("runner function returned error: %s", job_or_err), vim.log.level.INFO)
      return
    end

    vim.g._current_runner = job_or_err.pid

    -- Should kill on timeout.
    vim.defer_fn(function()
      if uv.kill(job_or_err.pid, 9) == 0 then
        vim.notify(string.format("previous script_runner timeout. current timeout: %d ms", timeout), vim.log.levels.INFO)
      end
    end, timeout)
  end

end, { desc = "Run current script. Use vim.bo.[filetype].runner to customize buffer local runner." })

vim.api.nvim_create_user_command("SetBufRunner",
  function(opts)
    local filetype = vim.bo.filetype
    local template = vim.trim(opts.args):gsub("^\"(.-)\"$", "%1")

    if not filetype or #filetype == 0 then
      vim.notify("invalid filetype", vim.log.levels.ERROR)
      return
    end
    if not template or #template == 0 then
      vim.notify("empty template", vim.log.levels.ERROR)
      return
    end
    vim.b.runner = vim.tbl_deep_extend("force", vim.b.runner or {}, {
      [filetype] = {
        runner = "",
        template = template,
      }
    })
  end,
  { desc = "buffer runner. e.g: SetBufRunner echo -e | /usr/bin/python3 <<EOF\n${text}\nEOF\n", nargs = 1 })

-- Tasks: Overseer
vim.api.nvim_create_user_command("OverseerRestartLast", function()
  local overseer = require("overseer")
  local tasks = overseer.list_tasks({ recent_first = true })
  if vim.tbl_isempty(tasks) then
    vim.notify("No tasks found", vim.log.levels.WARN)
  else
    overseer.run_action(tasks[1], "restart")
  end
end, {})

-- Neovim debugging server
vim.api.nvim_create_user_command("DebugServe", function(opt)
  local port = tonumber(opt.args or "8086")
  require("osv").launch({ port = port })
end, { nargs = "?" })

-- Mason
vim.api.nvim_create_user_command("MasonInstallAll", function(opts)
  local ensure_installed = require("mason").ensure_installed

  local to_install = {}
  if opts.args == nil or #opts.args == 0 then
    -- Install all.
    vim.print("No catergories pointed, installing all packages.")
    for _, packages in pairs(ensure_installed) do
      for i = 1, #packages do
        to_install[#to_install + 1] = packages[i]
      end
    end
  elseif ensure_installed[opts.args] then
    for i = 1, #packages do
      to_install[#to_install + 1] = ensure_installed[opts.args][i]
    end
  else
    vim.notify("catergory " .. opts.args .. " not defined. stopped.", vim.log.levels.ERROR)
    return
  end
  -- Dispose each item.
  for _, v in ipairs(to_install) do
    if type(v) == "function" then
      local fallback = v() -- If return string, fallback to mason install.
      if fallback and #fallback > 0 then
        v = fallback
      end
    end
    if type(v) == "string" then
      vim.schedule(function()
        if not require("mason").is_installed(v) then
          vim.cmd("MasonInstall " .. v)
        end
      end)
    end
  end
end, {
  desc = "Demand mason to install all the dependencies defined by `mason.ensure_installed`.",
  nargs = "?",
})

-- Open the launch.json related to the current workdir. If non-exists, confirms to create.
vim.api.nvim_create_user_command("OpenLaunchJson", function()
  -- Search .vscode/launch.json recursively above from the current working directory

  -- Try to find existing launch.json first
  local launch_json, vscode_dir = vim.g.find_launch_json(vim.fn.getcwd())

  -- If not found, use current working directory for creation
  if not launch_json then
    vscode_dir = vim.fn.getcwd() .. "/.vscode"
    launch_json = vscode_dir .. "/launch.json"
  end

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

-- Command to set up currrent tab name
vim.api.nvim_create_user_command("PinTab", function(opt)
  local current_id = vim.api.nvim_get_current_tabpage()
  local name = opt.args or ""

  -- if vim.g.pinned_tab and vim.g.pinned_tab.id == current_id and #name > 0 then
  --   -- If the current tab has been pinned. Update the name and fixed pages.
  --   -- TODO: fix buffers and windows.
  --   -- vim.g.pinned_tab.buffers = {}
  --   -- local windows = vim.api.nvim_tabpage_list_wins(current_id)
  --   -- for _, win in ipairs(windows) do
  --   --   local buffers = {}
  --   --   local seen = {}
  --   --
  --   --   for _, win in ipairs(windows) do
  --   --     local buf = vim.api.nvim_win_get_buf(win)
  --   --     if not seen[buf] then
  --   --       seen[buf] = true
  --   --       table.insert(buffers, buf)
  --   --     end
  --   --   end
  --   -- end
  --   vim.fn.settabvar(current_id, "tabname", name)
  --   vim.cmd("redrawtabline")
  -- else
  --   -- Else, set the current tab to be pinned.
  vim.g.pinned_tab = { id = current_id, name = "" }
  if name and #name > 0 then
    vim.fn.settabvar(vim.api.nvim_tabpage_get_number(current_id), "tabname", name)
    vim.g.pinned_tab.name = name
  end
  -- Move tab to the first.
  vim.cmd("tabmove 0")
  vim.cmd("redrawtabline")
  -- end
end, { desc = "Pin current tab", nargs = "?" })

vim.api.nvim_create_user_command("UnpinTab", function(opt)
  local current_id = vim.api.nvim_get_current_tabpage()

  vim.g.pinned_tab = nil
  vim.fn.settabvar(current_id, "tabname", "")
  vim.cmd("redrawtabline")
end, { desc = "Pin current tab", nargs = "?" })

vim.api.nvim_create_user_command("FlipPinnedTab", function(opt)
  if vim.g.pinned_tab == nil then
    return
  end
  local current_id = vim.api.nvim_get_current_tabpage()

  if vim.g.pinned_tab ~= nil and current_id == vim.g.pinned_tab.id then
    if vim.g.last_tab ~= nil and vim.g.last_lab ~= vim.g.pinned_tab.id then
      -- Go to the last visited tab. It must not be the current tabpage id.
      vim.api.nvim_set_current_tabpage(vim.g.last_tab)
    elseif #vim.api.nvim_list_tabpages() > 1 then
      -- Go to the first tabpage except the pinned tab if possible.
      vim.api.nvim_set_current_tabpage(vim.api.nvim_list_tabpages()[2])
    end
  elseif vim.g.pinned_tab ~= nil then
    -- We have pinned tab, but not the current one. Just go to the pinned tab.
    vim.api.nvim_set_current_tabpage(vim.g.pinned_tab.id)
  else
    -- We don't have any pinned tab. Just do nothing.
  end
end, { desc = "Go to and back from the pinned tab." })

vim.api.nvim_create_autocmd("TabLeave", {
  pattern = "*",
  callback = function()
    -- vim.print("TabLeave " .. vim.api.nvim_get_current_tabpage())
    if vim.g.pinned_tab == nil or vim.g.pinned_tab.id ~= vim.api.nvim_get_current_tabpage() then
      vim.g.last_tab = vim.api.nvim_get_current_tabpage()
    end
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  pattern = "*",
  callback = function()
    local closed_tab = vim.fn.expand("<afile>")
    if vim.g.pinned_tab and closed_tab == vim.g.pinned_tab.id then
      vim.cmd("UnpinTab")
    end
    if vim.g.last_tab == closed_tab then
      vim.g.last_tab = nil
    end
    -- Will be updated in another events.
  end,
})

-- Autoload files that has been changed. Triggers ":h autoread"
vim.api.nvim_create_autocmd("FocusGained", {
  pattern = "*",
  callback = function ()
    vim.cmd [[ checktime ]]
  end,
})


-- vim.api.nvim_create_autocmd("TabEnter", {
--   pattern = "*",
--   callback = function()
--     vim.print("TabEnter " .. vim.api.nvim_get_current_tabpage())
--   end,
-- })
-- vim.api.nvim_create_autocmd({ "TabEnter", "TabNew", "TabNewEntered", "TabClosed" }, {
--   pattern = "*",
--   callback = vim.g._update_tabs,
-- })

vim.api.nvim_create_user_command("SetTabName", function(opt)
  opt = opt or {}
  opt.args = opt.args or { "" }
  local tabname = opt.args
  vim.fn.settabvar(vim.fn.tabpagenr(), "tabname", tabname)
end, { desc = "Set the current tabname", nargs = "?" })

vim.api.nvim_create_user_command("ResetTabName", function()
  vim.fn.settabvar(vim.fn.tabpagenr(), "tabname", "")
end, { desc = "Reset the current tabname." })

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
        { item.trigger, "Special" },
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
      local align_2 = 0
      for _, snip in pairs(snippets) do
        align_2 = math.max(align_2, #snip.trigger)
      end
      local items = {}
      for _, snip in pairs(snippets) do
        local docstring = snip:get_docstring()
        if type(docstring) == "table" then
          docstring = table.concat(docstring)
        end
        local name = Snacks.picker.util.align(snip.name, align_1 + 3)
        local trigger = Snacks.picker.util.align(snip.trigger, align_2 + 3)
        local description = table.concat(snip.description)
        description = name == description and "" or description
        table.insert(items, {
          text = name .. description,
          name = name,
          description = description,
          trigger = trigger,
          orig_snip = snip,
          ft = snip.ft,
          preview = {
            ft = "json",
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
  if content then
    -- Actually move the filtered content to yanky register.
    require("yanky.history").push({
      regcontents = vim.trim(content),
      regtype = "y",
    })
  end
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

-- Svn Related.
if vim.g.modules.svn and vim.g.modules.svn.enabled then
  vim.api.nvim_create_user_command("SvnDiffShiftVersion", function(opts)
    opts = opts.args or "prev"

    -- Close the current tabpage
    local tab_debug = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug")
    if not tab_debug then
      vim.notify("not in the diff tab.", vim.log.levels.ERROR)
      return
    end
    local last_version =
      vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "tabname")

    -- Get all the svn editted versions for this file. Let's get 100 for the time being.
    local file_path = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) -- Get the file path of the buffer

    local version_handle = io.popen("svn log -q -l 100 " .. file_path .. " | grep \"^r[0-9]\" | cut -d ' ' -f 1") or {}
    local all_versions_str = version_handle:read("*all")
    version_handle:close()

    -- Scan the results from all versions.
    local all_versions = {}
    for version in all_versions_str:gmatch("([^\r\n]+)") do
      if version and #version > 0 then
        table.insert(all_versions, version)
      end
    end

    -- Search next version.
    local current_index = nil
    for i, version in ipairs(all_versions) do
      if version == last_version then
        current_index = i
        break
      end
    end

    if not current_index then
      vim.notify("Current version '" .. last_version .. "' not found in SVN history", vim.log.levels.ERROR)
      return
    end

    local target_index
    if opts == "prev" then
      -- Previous version (older, higher index since list is descending)
      target_index = current_index + 1
    elseif opts == "next" then
      -- Next version (newer, lower index since list is descending)
      target_index = current_index - 1
    else
      vim.notify("Invalid option '" .. opts .. "'. Use 'prev' or 'next'", vim.log.levels.ERROR)
      return
    end

    if target_index < 1 then
      vim.print_silent("No newer version available (already at newest)")
      return
    end

    if target_index > #all_versions then
      vim.print_silent("No older version available (already at oldest)")
      return
    end

    local target_version = all_versions[target_index]

    -- Close current diff tab and open new one with target version
    vim.cmd("tabclose")
    vim.cmd("SvnDiffThis " .. target_version:gsub("^r", "")) -- Remove 'r' prefix for svn command
  end, { desc = "Close the svn diff tab." })

  vim.api.nvim_create_user_command("SvnDiffThisClose", function()
    -- Close the current tabpage
    local tab_debug = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug")
    if tab_debug then
      vim.cmd("tabclose")
    else
      vim.notify("not in the diff tab.", vim.log.levels.ERROR)
    end
  end, { desc = "Close the svn diff tab." })

  -- SVN diff locally.
  vim.api.nvim_create_user_command("SvnDiffThis", function(opts)
    local demanded_version = opts.args

    -- Get the current buffer's filetype, index, and file path
    local buf_number = vim.api.nvim_get_current_buf() -- Get the current buffer number
    local file_path = vim.api.nvim_buf_get_name(buf_number) -- Get the file path of the buffer
    local filetype = vim.bo[buf_number].filetype -- Get the filetype of the buffer

    -- Create a new tab
    vim.cmd("tabnew")

    -- Judge the svn version of the file.
    local svn_version_cmd = "svn info " .. file_path
    svn_version_cmd = svn_version_cmd .. " | grep Revision:"
    svn_version_cmd = svn_version_cmd .. " | awk '{print $2}'"
    local version_handle = io.popen(svn_version_cmd) or {}
    local version = version_handle:read("*all")

    -- Mark current tabpage. Name & svn debug.
    vim.fn.settabvar(vim.api.nvim_get_current_tabpage(), "tabname", version)
    vim.fn.settabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug", true)

    -- Name for the versioned buffer.
    local old_version_buffer_name = file_path .. ":" .. version

    vim.cmd("vsplit")

    -- Try to get the file content from SVN (svn cat) if not existing.
    -- FIXME: Buffer with this name already exists
    --
    if vim.fn.bufloaded(old_version_buffer_name) <= 0 then
      vim.print("dont exists")
      -- not opened.
      local svn_cmd = "svn cat " .. file_path
      if demanded_version and #demanded_version > 0 then
        svn_cmd = svn_cmd .. " -r " .. demanded_version
      end
      svn_cmd = svn_cmd .. " | iconv -f GBK -t UTF-8 " -- now workaround for GBK.  TODO: zianxu: auto detect from fileencodings.
      svn_cmd = svn_cmd .. " | sed s/^M//g "
      local handle = io.popen(svn_cmd) or {}
      local svn_content = handle:read("*all")
      local success = handle:close() -- Capture the exit code to check if svn command succeeded

      local buf2
      if success and svn_content and #svn_content > 0 then
        buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf2, 0, -1, false, vim.split(string.gsub(svn_content, "\n$", ""), "\n"))
        -- TODO: Judge error type.
      else
        -- If it's new buffer, create an empty buffer
        vim.print("svn cat error: svn command: " .. svn_cmd)
        buf2 = vim.api.nvim_create_buf(false, true) -- Create an empty buffer
      end
      vim.api.nvim_win_set_buf(0, buf2)
      vim.bo[buf2].modifiable = false
      vim.bo[buf2].filetype = filetype
      vim.cmd("file " .. old_version_buffer_name)
    else
      -- Exist. Just switch to it.
      vim.print("exists")
      vim.cmd("buffer " .. old_version_buffer_name)
    end

    -- Original buffer in vertical split right side. Cursor stays left side.
    vim.cmd("wincmd l")
    vim.cmd("edit " .. file_path) -- already opened.

    vim.cmd("windo diffthis")
  end, { desc = "SVN diff this file in a new tabpage.", nargs = "?" })

  vim.api.nvim_create_user_command("SvnDiffAll", function()
    local function parse_file_changes(input)
      local file_changes = {}
      -- Iterate through each line of the input
      for line in input:gmatch("[^\r\n]+") do
        local operation, filepath = line:match("^(%S+)%s+(%S+)")
        if operation and filepath then
          table.insert(file_changes, { status = operation, text = filepath, file = filepath })
        end
      end
      return file_changes
    end

    local svn_updates = function()
      local command = 'svn status | grep -e "^[A|M]"'
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return parse_file_changes(result)
    end

    -- vim.print(svn_updates())

    require("snacks").picker({
      finder = svn_updates,
      -- layout = {
      --     preview = false,
      -- }
    })
  end, { desc = "List all svn modifications." })
end

-- Oldfiles related.
-- Save & load the pages in record after entering buffer.
-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = "*",
--   -- Async write and load shada files.
--   callback = vim.schedule_wrap(function()
--     vim.cmd([[ wshada ]])
--     vim.cmd([[ rshada! ]])
--   end),
-- })

-- Highlight related.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "*" },
  callback = function()
    if vim.tbl_contains(vim.g.use_treesitter_highlight, vim.bo.filetype) then
      vim.cmd([[ TSBufEnable highlight ]])
    else
      vim.bo.syntax = "on"
    end
  end,
})

-- Quickfix related.
-- Page closing
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "gitsigns-blame" },
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
vim.api.nvim_create_user_command("Split", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cmd>split<cr><c-w>j", true, false, true), "n", false)
end, { desc = "split horizontally and move cursor" })
vim.api.nvim_create_user_command("Vsplit", function()
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
local snack_old_file = function()
  local title = "OldFiles"
  return function()
    Snacks.picker.pick({
      global = false,
      toggles = {
        global = "g",
      },
      title = title,
      format = function(item, picker)
        local ret = require("snacks.picker.format").filename(item, picker)
        -- ret[#ret + 1] = { item.text }
        return ret
      end,
      finder = function(picker, _)
        local cwd = vim.fs.normalize(vim.fn.getcwd())
        local oldfile_items = vim.v.oldfiles
        if #oldfile_items == 0 then
          vim.print_silent("Oldfiles picker: No old files.")
          return {}
        end

        local tbl = {}
        for _, oldfile in ipairs(oldfile_items) do
          local full_path = vim.fs.normalize(oldfile)
          if not picker.global and full_path:find(cwd, 1, true) ~= 1 then
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
        toggle_local = function(picker)
          picker.opts.global = not picker.opts.global
          picker:find()
        end,
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

vim.api.nvim_create_user_command("SnackOldfiles", snack_old_file(), { desc = "Open oldfiles." })

-- Bookmark related code snippet.
vim.api.nvim_create_user_command("BookmarkGrepMarkedFiles", function()
  local Repo = require("bookmarks.domain.repo")
  local Node = require("bookmarks.domain.node")
  local active_list = Repo.ensure_and_get_active_list()
  local bookmarks = Node.get_all_bookmarks(active_list)

  -- Get unique file paths from bookmarks
  local files = {}
  local seen = {}
  for _, bookmark in ipairs(bookmarks) do
    if not seen[bookmark.location.path] then
      seen[bookmark.location.path] = true
      table.insert(files, bookmark.location.path)
    end
  end

  local search_content = ""
  if vim.tbl_contains({ "v", "V", "s" }, vim.fn.mode()) then
    search_content = vim.g.function_get_selected_content()
  end

  -- Call snacks to grep through these files.
  Snacks.picker.grep({
    title = "Grep Bookmarked Files",
    dirs = files,
    hidden = true,
    search = search_content,
  })
end, { desc = "Remove the bookmark at cursor line.", nargs = "?" })
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
        local delete_from_bookmark = function(local_picker, local_item)
          local location = local_item.bm_location
          local node = require("bookmarks.domain.repo").find_node_by_location(location)
          if not node then
            vim.notify("No node found at cursor position", vim.log.levels.WARN)
            return
          end
          require("bookmarks.domain.service").delete_node(node.id)
          require("bookmarks.sign").safe_refresh_signs()
          local_picker.list:set_selected()
          local_picker.list:set_target()
          local_picker:find()
        end
        local sel = picker:selected()
        local items = #sel > 0 and sel or { item }
        for _, item in pairs(items) do
          delete_from_bookmark(picker, item)
        end
      end,
      -- delete_from_bookmarks = function(picker, item)
      -- end,
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
          ["<c-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<d-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<c-e>"] = { "edit_bookmark", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<c-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<d-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
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

vim.api.nvim_create_user_command("ClearBookmark", function(opt)
  opt = opt.args[1] or "wasted"
  local all_bookmarks =
    require("bookmarks.domain.node").get_all_bookmarks(require("bookmarks.domain.repo").ensure_and_get_active_list())
  local to_remove_bookmarks = {}
  if opt == "all" then
    -- clear all bookmarks.
    to_remove_bookmarks = all_bookmarks
  elseif opt == "wasted" then
    -- clear bookmarks with pending path reference.
    for _, bookmark in ipairs(all_bookmarks) do
      if vim.fn.filereadable(bookmark.location.path) == 0 then
        table.insert(to_remove_bookmarks, bookmark)
      end
    end
  end
  for _, bookmark in ipairs(to_remove_bookmarks) do
    vim.notify("Remove bookmark: " .. bookmark.location.path, vim.log.levels.DEBUG)
    require("bookmarks.domain.service").delete_node(bookmark.id)
  end
  vim.print("Cleared " .. #to_remove_bookmarks .. " bookmarks.")
  require("bookmarks.sign").safe_refresh_signs()
end, { desc = "Remove the bookmark at cursor line.", nargs = "?" })

-- Set cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
if vim.fn.has("nvim-0.11") == 1 then
  -- Neovim added t mode for guicursor in nvim-0.11, and gave up drawing terminal mode.
  vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:ver25"
end

-- vim.api.nvim_create_autocmd({
--   "TermOpen",
--   "WinEnter",
-- }, {
--   pattern = "term://*",
--   command = "startinsert",
-- })
--
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
  local _, row, col, _ = unpack(vim.fn.getpos("."))
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
    else
      vim.cmd("wincmd h")
    end
  elseif opt == "j" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("split")
    end
    vim.cmd("wincmd j")
  elseif opt == "k" then
    if vim.fn.winnr() == vim.fn.winnr(opt) then
      vim.cmd("split")
    else
      vim.cmd("wincmd k")
    end
  end
  vim.cmd("b " .. buf)
  vim.cmd("call cursor" .. "(" .. row .. "," .. col .. ")")

  vim.cmd("wincmd p") -- go to the last win.
  require("bufjump").backward()
  -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-o>", true, false, true), "n", false)

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
  local ret = ""
  if opt == "full" then
    -- /path/to/cwd/filename.ext
    ret = vim.fn.expand("%:p")
  elseif opt == "relative" then
    -- ./path/relative/to/cwd/filename.ext
    local escaped_cwd = vim.fn.getcwd():gsub("([%.%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
    ret = vim.fn.expand("%:p"):gsub(escaped_cwd .. "/", "")
  elseif opt == "dir" then
    -- /path/to/cwd/
    ret = vim.fn.getcwd()
  elseif opt == "filename" then
    -- filename.ext
    ret = vim.fn.expand("%:t")
  elseif opt == "line" then
    -- filename.ext:line
    local _, line, _, _ = unpack(vim.fn.getpos("."))
    ret = vim.fn.expand("%:t") .. ":" .. line
  else
    vim.notify("Invalid option: " .. opt, vim.log.levels.ERROR)
  end
  vim.fn.setreg("*", ret)
  vim.print_silent("Copied: " .. ret)
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
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    -- Detach from tmux shell.
    -- Try to detach from the subprocess.
    local tmux_client_pid = vim.g.__tmux_get_current_attached_cliend_pid()
    if tmux_client_pid and #tmux_client_pid > 0 then
      for _, pid in ipairs(tmux_client_pid) do
        if #pid > 0 then
          vim.cmd("!kill -s SIGHUP " .. pid)
        end
      end
    else
      vim.cmd("!tmux detach -s " .. (vim.g.terminal_default_tmux_session_name or "nvim-attached"))
    end
    -- https://github.com/neovim/neovim/issues/21856
    vim.cmd("!tmux detach -s " .. (vim.g.terminal_default_tmux_session_name or "nvim-attached"))
    vim.cmd("sleep 10m")
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
vim.api.nvim_create_user_command("DapTerminate", function()
  require("dap").terminate()
end, {})

-- dap repl autocomplete
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "dap-repl",
--   callback = function()
--     require('dap.ext.autocompl').attach()
--   end,
-- })

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

-- Avante keymaps.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "Avante" },
  callback = function()
    vim.keymap.set(
      "n",
      "<c-c>",
      require("avante.api").stop,
      { desc = "Stop avante generation in avante window.", silent = true, buffer = true, noremap = false }
    )
  end,
})

-- Neovide transparency control
vim.api.nvim_create_user_command("NeovideTransparentToggle", function()
  if vim.g._neovide_background_color then
    vim.g.neovide_background_color = vim.g._neovide_background_color
  else
    vim.g._neovide_background_color = vim.g.neovide_background_color
    if #vim.g.neovide_background_color > 7 then
      vim.g.neovide_background_color = string.sub(vim.g.neovide_background_color, 1, 7)
    end
  end
end, {})
