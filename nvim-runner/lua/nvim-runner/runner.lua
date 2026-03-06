-- nvim-runner/lua/nvim-runner/runner.lua
-- Core RunScript logic

local config = require("nvim-runner.config")
local util = require("nvim-runner.util")

local M = {}

-- Track the current running process
M._current_runner = nil

--- Kill the current runner if any
function M.kill_current()
  if M._current_runner then
    local uv = vim.uv or vim.loop
    pcall(uv.kill, M._current_runner, 9)
    M._current_runner = nil
    return true
  end
  return false
end

--- Run script for the current buffer
function M.run()
  local uv = vim.uv or vim.loop
  local opts = config.options

  local bufid = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  -- Choose runner: buffer-local > predefined
  local all_runners = vim.b["runner"] or {}
  if #vim.bo.filetype == 0 then
    vim.notify("No filetype detected.", vim.log.levels.ERROR)
    return
  end

  local runner = all_runners[vim.bo.filetype] or opts.runners[vim.bo.filetype]
  if not runner then
    vim.notify("No runner found for filetype: " .. vim.bo.filetype, vim.log.levels.ERROR)
    return
  end

  -- Get text: selected > full text
  local text_literal = ""
  if util.is_in_visual_mode() then
    text_literal = util.get_selected_content()
  else
    text_literal = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  end

  -- Resolve runner executable
  local runner_literal = ""
  if not runner.runner then
    -- possibly using runner hardcoded in template
  elseif type(runner.runner) == "string" then
    runner_literal = runner.runner
  elseif type(runner.runner) == "function" then
    runner_literal = runner.runner()
    -- false or nil
    if not runner_literal then
      vim.notify("runner function returned abortion.", vim.log.levels.INFO) -- FIXED_BUG: was vim.log.level.INFO
      return
    end
  else
    vim.notify("Runner template is not qualified", vim.log.levels.ERROR)
    return
  end
  assert(type(runner_literal) == "string")

  -- Resolve template
  local template_literal = ""
  if type(runner.template) == "string" then
    template_literal = runner.template
  elseif type(runner.template) == "function" then
    template_literal = runner.template(runner_literal, text_literal)
    -- false or nil
    if not template_literal then
      vim.notify("template function returned abortion.", vim.log.levels.INFO) -- FIXED_BUG: was vim.log.level.INFO
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

  -- Resolve timeout (in ms)
  -- FIXED_BUG: Original had operator precedence issue and mixed seconds/ms units
  local timeout = opts.timeout or 3000 -- default fallback in ms
  local timeout_candidates = {
    vim.g._runner_global_timeout,
    runner.timeout,
  }
  -- Also check filetype_runner default timeout if different from the runner
  local ft_default = opts.runners[vim.bo.filetype]
  if ft_default and ft_default ~= runner then
    table.insert(timeout_candidates, ft_default.timeout)
  end

  for _, candidate in ipairs(timeout_candidates) do
    -- FIXED_BUG: was `candidate and type(candidate) == "number" or candidate > 0`
    -- which has operator precedence issue. Fixed with proper parentheses.
    if candidate and (type(candidate) == "number" and candidate > 0) then
      timeout = candidate
      break
    end
  end

  -- Kill previous runner before starting new one
  -- FIXED_BUG: Original killed in the callback (race condition).
  -- Now we kill before starting the new one.
  if M._current_runner then
    pcall(uv.kill, M._current_runner, 9)
    vim.notify("stopped previous running script.", vim.log.levels.INFO)
    M._current_runner = nil
  end

  -- Execute
  if vim.bo.filetype == "lua" and runner_literal == "this_neovim" then
    local func, errmsg = loadstring(template_literal)
    if not func then
      vim.notify("neovim lua: failed to parse lua code block: \n" .. errmsg, vim.log.levels.ERROR)
    else
      assert(type(func) == "function")
      vim.print(func() or "lua executed.")
    end
    -- No timeout function for built-in types
  else
    vim.print(template_literal)
    local ok, job_or_err = pcall(
      vim.system,
      {
        vim.o.shell,
        "-c",
        template_literal,
      },
      {
        text = true,
      },
      -- Report result to cursor position or end of the document when runner ends
      vim.schedule_wrap(function(obj)
        M._current_runner = nil
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

        if #return_text <= 1 then
          -- FIXED_BUG: was `string(obj.code)` — `string` is not a Lua global function, use `tostring`
          vim.notify("script_runner ends with nothing: " .. tostring(obj.code))
          return
        end
        return_text = string.gsub(return_text, "\n+$", "") .. "\n"

        if opts.insert_result then
          -- Set the undo checkpoint for quick undo
          vim.cmd([[ let &ul=&ul ]])

          -- Insert at the cursor position
          local pos = {}
          if vim.api.nvim_get_current_buf() ~= bufid then
            vim.notify("script_runner finished in another buf.", vim.log.levels.INFO)
            pos = vim.api.nvim_buf_get_mark(bufid, '"')
          else
            pos = vim.api.nvim_win_get_cursor(winid)
          end
          vim.api.nvim_buf_set_lines(bufid, pos[1], pos[1], false, vim.split(return_text, "\n"))
        end
      end)
    )

    if not ok then
      vim.notify(string.format("runner function returned error: %s", job_or_err), vim.log.levels.INFO) -- FIXED_BUG: was vim.log.level.INFO
      return
    end

    M._current_runner = job_or_err.pid

    -- Kill on timeout
    -- FIXED_BUG: Original timeout values were in seconds (3, 5) but vim.defer_fn uses ms.
    -- Now all timeout values are consistently in ms.
    vim.defer_fn(function()
      if M._current_runner == job_or_err.pid then
        if pcall(uv.kill, job_or_err.pid, 9) then
          vim.notify(
            string.format("previous script_runner timeout. current timeout: %d ms", timeout),
            vim.log.levels.INFO
          )
        end
        M._current_runner = nil
      end
    end, timeout)
  end
end

return M
