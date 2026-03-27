-- User commands extracted from autocmds.lua

vim.api.nvim_create_user_command("Copen", "botright copen", { desc = "Open quick fix list full wide" })

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
    local uv = vim.uv
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
          require('venv-selector').python() or "",
            "python3",
            "python"
          }
          local found = false
          local python_interpreter = ""
          for _, candidate in ipairs(candidates) do
            if vim.fn.executable(candidate) ~= 0 then
              python_interpreter = candidate
              found = true
              break
            end
          end
          if not found or #python_interpreter == 0 then
            vim.notify("no usable python interpreter.", vim.log.levels.ERROR)
            return ""
          end
          return python_interpreter
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
      vim.notify("runner function returned abortion.", vim.log.levels.INFO)
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
      vim.notify("template function returned abortion.", vim.log.levels.INFO)
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
  -- Priority: global override > buffer-local runner > filetype default > fallback 3000ms
  local timeout = 3000
  local timeout_candidates = {
    filetype_runner[vim.bo.filetype] and filetype_runner[vim.bo.filetype].timeout or nil,
    runner.timeout or nil,
    vim.g._runner_global_timeout or nil,
  }
  for _, candidate in ipairs(timeout_candidates) do
    if candidate and type(candidate) == "number" and candidate > 0 then
      -- Runner timeouts are defined in seconds, convert to ms
      timeout = candidate * 1000
    end
  end

  -- As the runner is designed to be transient, we are just using global runner here.
  -- You can always use ctrl-C to stop it.
  if vim.bo.filetype == "lua" and runner_literal == "this_neovim" then
    local func, errmsg = loadstring(template_literal)
    if not func then
      vim.notify("neovim lua: failed to parse lua code block: \n" .. errmsg, vim.log.levels.ERROR)
    else
      assert(type(func) == "function")
      vim.print_silent(func() or "lua executed.")
    end
    -- TODO: no timeout function for built-in types now.
  else
    vim.print(template_literal)
    local ok, job_or_err = pcall(
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
          vim.notify("script_runner ends with nothing: " .. tostring(obj.code))
          return
        end
        return_text = string.gsub(return_text, "\n+$", "") .. "\n"

        -- Set the undo checkpoint for quick undo.
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
      vim.notify(string.format("runner function returned error: %s", job_or_err), vim.log.levels.INFO)
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
  if opt.args == "stop" then
    require("osv").stop()
    return
  end
  local port = tonumber(opt.args) or 8086
  require("osv").launch({ port = port })
end, { nargs = "?" })

-- Mason
vim.api.nvim_create_user_command("MasonInstallAll", function(opts)
  local ensure_installed = require("mason").ensure_installed

  local to_install = {}
  if opts.args == nil or #opts.args == 0 then
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
  for _, v in ipairs(to_install) do
    if type(v) == "function" then
      local fallback = v()
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

-- Open the launch.json related to the current workdir.
vim.api.nvim_create_user_command("OpenLaunchJson", function()
  local launch_json, vscode_dir = vim.g.find_launch_json(vim.fn.getcwd())

  if not launch_json then
    vscode_dir = vim.fn.getcwd() .. "/.vscode"
    launch_json = vscode_dir .. "/launch.json"
  end

  if vim.fn.filereadable(launch_json) == 0 then
    local choice = vim.fn.confirm("launch.json does not exist. Create it?", "&Yes\n&No", 1)
    if choice == 1 then
      local template = [[
{
  "version": "0.2.0",
  "configurations": []
}
]]
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

-- Tab management commands
vim.api.nvim_create_user_command("PinTab", function(opt)
  local current_id = vim.api.nvim_get_current_tabpage()
  local name = opt.args or ""

  vim.g.pinned_tab = { id = current_id, name = "" }
  if name and #name > 0 then
    vim.fn.settabvar(vim.api.nvim_tabpage_get_number(current_id), "tabname", name)
    vim.g.pinned_tab.name = name
  end
  vim.cmd("tabmove 0")
  vim.cmd("redrawtabline")
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
    if vim.g.last_tab ~= nil and vim.g.last_tab ~= vim.g.pinned_tab.id then
      vim.api.nvim_set_current_tabpage(vim.g.last_tab)
    elseif #vim.api.nvim_list_tabpages() > 1 then
      vim.api.nvim_set_current_tabpage(vim.api.nvim_list_tabpages()[2])
    end
  elseif vim.g.pinned_tab ~= nil then
    vim.api.nvim_set_current_tabpage(vim.g.pinned_tab.id)
  end
end, { desc = "Go to and back from the pinned tab." })

vim.api.nvim_create_user_command("SetTabName", function(opt)
  opt = opt or {}
  opt.args = opt.args or { "" }
  local tabname = opt.args
  vim.fn.settabvar(vim.fn.tabpagenr(), "tabname", tabname)
end, { desc = "Set the current tabname", nargs = "?" })

vim.api.nvim_create_user_command("ResetTabName", function()
  vim.fn.settabvar(vim.fn.tabpagenr(), "tabname", "")
end, { desc = "Reset the current tabname." })

-- Snippet commands
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
  vim.print_silent("Editing lua script. Call :SnipLoad on accomplishment.")
end, { desc = "Open the lua snippet buffer. By default, open the all.json under vim config dir." })

vim.api.nvim_create_user_command("SnipLoad", function()
  if vim.g.import_user_snippets then
    require("luasnip.loaders.from_vscode").load({
      paths = vim.g.user_vscode_snippets_path,
    })
    vim.print_silent("snip load success.")
  end
end, { desc = "Load luasnip files." })

-- Lua print target result content.
vim.api.nvim_create_user_command("LuaPrint", function()
  local codepiece, err = loadstring("vim.print(" .. vim.g.function_get_selected_content() .. ")")
  if err then
    vim.print("failed to execute target string: " .. err)
  else
    codepiece()
  end
end, { desc = "Execute the target lua codepiece and print result", range = true })

-- SVN commands
if vim.g.modules.svn and vim.g.modules.svn.enabled then
  vim.api.nvim_create_user_command("SvnDiffShiftVersion", function(opts)
    opts = opts.args or "prev"

    local tab_debug = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug")
    if not tab_debug then
      vim.notify("not in the diff tab.", vim.log.levels.ERROR)
      return
    end
    local last_version =
      vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "tabname")

    local file_path = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

    local version_handle = io.popen("svn log -q -l 100 " .. file_path .. " | grep \"^r[0-9]\" | cut -d ' ' -f 1") or {}
    local all_versions_str = version_handle:read("*all")
    version_handle:close()

    local all_versions = {}
    for version in all_versions_str:gmatch("([^\r\n]+)") do
      if version and #version > 0 then
        table.insert(all_versions, version)
      end
    end

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
      target_index = current_index + 1
    elseif opts == "next" then
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

    vim.cmd("tabclose")
    vim.cmd("SvnDiffThis " .. target_version:gsub("^r", ""))
  end, { desc = "Close the svn diff tab." })

  vim.api.nvim_create_user_command("SvnDiffThisClose", function()
    local tab_debug = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug")
    if tab_debug then
      vim.cmd("tabclose")
    else
      vim.notify("not in the diff tab.", vim.log.levels.ERROR)
    end
  end, { desc = "Close the svn diff tab." })

  vim.api.nvim_create_user_command("SvnDiffThis", function(opts)
    local demanded_version = opts.args

    local buf_number = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(buf_number)
    local filetype = vim.bo[buf_number].filetype

    vim.cmd("tabnew")

    local svn_version_cmd = "svn info " .. file_path
    svn_version_cmd = svn_version_cmd .. " | grep Revision:"
    svn_version_cmd = svn_version_cmd .. " | awk '{print $2}'"
    local version_handle = io.popen(svn_version_cmd) or {}
    local version = version_handle:read("*all")

    vim.fn.settabvar(vim.api.nvim_get_current_tabpage(), "tabname", version)
    vim.fn.settabvar(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()), "svn_debug", true)

    local old_version_buffer_name = file_path .. ":" .. version

    vim.cmd("vsplit")

    if vim.fn.bufloaded(old_version_buffer_name) <= 0 then
      vim.print("dont exists")
      local svn_cmd = "svn cat " .. file_path
      if demanded_version and #demanded_version > 0 then
        svn_cmd = svn_cmd .. " -r " .. demanded_version
      end
      svn_cmd = svn_cmd .. " | iconv -f GBK -t UTF-8 "
      svn_cmd = svn_cmd .. " | sed s/^M//g "
      local handle = io.popen(svn_cmd) or {}
      local svn_content = handle:read("*all")
      local success = handle:close()

      local buf2
      if success and svn_content and #svn_content > 0 then
        buf2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf2, 0, -1, false, vim.split(string.gsub(svn_content, "\n$", ""), "\n"))
      else
        vim.print("svn cat error: svn command: " .. svn_cmd)
        buf2 = vim.api.nvim_create_buf(false, true)
      end
      vim.api.nvim_win_set_buf(0, buf2)
      vim.bo[buf2].modifiable = false
      vim.bo[buf2].filetype = filetype
      vim.cmd("file " .. old_version_buffer_name)
    else
      vim.print("exists")
      vim.cmd("buffer " .. old_version_buffer_name)
    end

    vim.cmd("wincmd l")
    vim.cmd("edit " .. file_path)
    vim.cmd("windo diffthis")
  end, { desc = "SVN diff this file in a new tabpage.", nargs = "?" })

  vim.api.nvim_create_user_command("SvnDiffAll", function()
    local function parse_file_changes(input)
      local file_changes = {}
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

    require("snacks").picker({
      finder = svn_updates,
    })
  end, { desc = "List all svn modifications." })
end

-- Quickfix navigation
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

-- Window splitting with cursor moved to the new one.
vim.api.nvim_create_user_command("Split", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cmd>split<cr><c-w>j", true, false, true), "n", false)
end, { desc = "split horizontally and move cursor" })
vim.api.nvim_create_user_command("Vsplit", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<cmd>vsplit<cr><c-w>l", true, false, true), "n", false)
end, { desc = "split horizontally and move cursor" })

-- Neovide
vim.api.nvim_create_user_command("NeovideNew", function()
  vim.cmd([[ ! open -n "/Applications/Neovide.app" --args --grid 80x25 ]])
end, {})

-- Search History
vim.api.nvim_create_user_command("SearchHistory", function()
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker and snacks.picker.search_history then
    snacks.picker.search_history()
  else
    vim.notify("Snacks.picker not available", vim.log.levels.WARN)
  end
end, {})

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

  vim.cmd("wincmd p")
  require("bufjump").backward()

  vim.cmd("wincmd p")
end, { nargs = "?" })

-- Open in Vscode
vim.api.nvim_create_user_command("Code", function(opt)
  local mode
  if #opt.args == 0 then
    mode = "full"
  else
    mode = opt.args
  end

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
    vim.uv.spawn(code, {
      args = { dir },
    })
  end
  if file then
    vim.uv.spawn(code, {
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
    ret = vim.fn.expand("%:p")
  elseif opt == "relative" then
    local escaped_cwd = vim.fn.getcwd():gsub("([%.%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
    ret = vim.fn.expand("%:p"):gsub(escaped_cwd .. "/", "")
  elseif opt == "dir" then
    ret = vim.fn.getcwd()
  elseif opt == "filename" then
    ret = vim.fn.expand("%:t")
  elseif opt == "line" then
    local _, line, _, _ = unpack(vim.fn.getpos("."))
    ret = vim.fn.expand("%:t") .. ":" .. line
  else
    vim.notify("Invalid option: " .. opt, vim.log.levels.ERROR)
  end
  vim.fn.setreg("*", ret)
  vim.print_silent("Copied: " .. ret)
end, { nargs = "?" })

-- Navigatin Z wrapper
vim.api.nvim_create_user_command("Cd", function(opts)
  opts = opts or ""
  vim.cmd('silent !zoxide add "' .. opts.args .. '"')
  vim.cmd("cd " .. opts.args)
  vim.cmd("pwd")
end, { nargs = "?" })

-- TelescopeAutoCommands removed: telescope.nvim was removed (issue #45)

-- Lint
local function lint()
  require("lint").try_lint()
end
vim.api.nvim_create_user_command("Lint", lint, {})

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

vim.api.nvim_create_user_command("DapTerminate", function()
  require("dap").terminate()
end, {})

-- Custom Simple Commands.
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

-- Bookmark commands
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
    to_remove_bookmarks = all_bookmarks
  elseif opt == "wasted" then
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

-- Obsidian commands
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

vim.api.nvim_create_user_command("ObsUnlink", function()
  CommandCheckBefore()
  local current_file = vim.fn.expand("%:p", nil, nil)
  vim.cmd([[ :w ]])
  if vim.fn.fnamemodify(current_file, ":e") ~= "md" then
    vim.notify("The current file is not a Markdown file. Stopped.", vim.log.levels.ERROR)
    return
  end
  local destination = VaultMap(current_file)

  local cmd = string.format("rm %s", vim.fn.shellescape(destination))
  local success, std = vim.g.shell_run(cmd)
  if not success then
    vim.notify("Error Unlinking file: " .. (std or ""), vim.log.levels.ERROR)
    return
  else
    vim.notify("Link " .. destination .. " removed: " .. (std or ""), vim.log.levels.INFO)
  end
end, {})

vim.api.nvim_create_user_command("ObsOpen", function()
  CommandCheckBefore()

  local current_file = vim.fn.expand("%:p", nil, nil)
  vim.cmd([[ :w ]])
  if vim.fn.fnamemodify(current_file, ":e") ~= "md" then
    vim.notify("The current file is not a Markdown file. Stopped.", vim.log.levels.ERROR)
    return
  end

  local destination = VaultMap(current_file)
  local f = io.open(destination, "r")
  if f == nil then
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
end, {})

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
