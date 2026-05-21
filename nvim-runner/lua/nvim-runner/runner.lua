-- nvim-runner/lua/nvim-runner/runner.lua
-- Core RunScript logic

local config = require("nvim-runner.config")
local util = require("nvim-runner.util")

local M = {}

-- Track the current running process
M._current_runner = nil

-- Track scratch buffers by filetype to avoid E95 (buffer name conflict)
M._scratch_buffers = {}

--- Safe string replacement that avoids gsub pattern/replacement special chars.
--- Uses plain string.find to locate the pattern, then concatenates.
--- Only replaces the first occurrence.
---@param s string the source string
---@param target string the literal string to find
---@param replacement string the literal replacement
---@return string
local function safe_replace(s, target, replacement)
  local i, j = s:find(target, 1, true) -- plain find
  if not i then
    return s
  end
  return s:sub(1, i - 1) .. replacement .. s:sub(j + 1)
end

--- Safe string replacement that replaces ALL occurrences.
---@param s string the source string
---@param target string the literal string to find
---@param replacement string the literal replacement
---@return string
local function safe_replace_all(s, target, replacement)
  local result = {}
  local pos = 1
  local target_len = #target
  if target_len == 0 then
    return s
  end
  while true do
    local i, j = s:find(target, pos, true)
    if not i then
      table.insert(result, s:sub(pos))
      break
    end
    table.insert(result, s:sub(pos, i - 1))
    table.insert(result, replacement)
    pos = j + 1
  end
  return table.concat(result)
end

-- Expose for testing
M._safe_replace = safe_replace
M._safe_replace_all = safe_replace_all

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

--- Resolve timeout with proper priority:
--- buffer-local (vim.b.runner_timeout) > runner-defined > setup() global > default 3000ms
---@param runner_def table the runner definition
---@param bufnr number buffer number
---@return number timeout in ms
local function resolve_timeout(runner_def, bufnr)
  -- 1. buffer-local timeout (highest priority)
  local buf_timeout = vim.b[bufnr].runner_timeout
  if buf_timeout and type(buf_timeout) == "number" and buf_timeout > 0 then
    return buf_timeout
  end

  -- 2. runner-defined timeout
  if runner_def.timeout and type(runner_def.timeout) == "number" and runner_def.timeout > 0 then
    return runner_def.timeout
  end

  -- 3. setup() global timeout
  local opts = config.options
  if opts.timeout and type(opts.timeout) == "number" and opts.timeout > 0 then
    return opts.timeout
  end

  -- 4. default
  return 3000
end

-- Expose for testing
M._resolve_timeout = resolve_timeout

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
      vim.notify("runner function returned abortion.", vim.log.levels.INFO)
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
      vim.notify("template function returned abortion.", vim.log.levels.INFO)
      return
    end
  else
    vim.notify("Runner template is not qualified", vim.log.levels.ERROR)
    return
  end
  assert(type(template_literal) == "string")

  -- Assemble command using safe replacement (avoids gsub % special char issues)
  -- Order matters: replace ${runner} first, then ${text}
  -- (${text} content might contain "${runner}" literally, so this order is safe)
  template_literal = safe_replace_all(template_literal, "${runner}", runner_literal)
  template_literal = safe_replace_all(template_literal, "${text}", text_literal)

  -- Resolve timeout with proper priority
  local timeout = resolve_timeout(runner, bufid)

  -- Kill previous runner before starting new one
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

        -- Enhance error reporting when command fails
        if obj.code ~= 0 then
          local error_header = string.format("--- ERROR (exit code %d) ---\n", obj.code)
          local cmd_line = "Command: " .. template_literal .. "\n"
          if #return_text <= 1 then
            return_text = "\n" .. error_header .. cmd_line .. "(no output)\n"
          else
            return_text = "\n" .. error_header .. cmd_line .. return_text
          end
        end

        if #return_text <= 1 then
          vim.notify("script_runner ends with nothing: " .. tostring(obj.code))
          return
        end
        return_text = string.gsub(return_text, "\n+$", "") .. "\n"

        if opts.insert_result then
          -- Determine output mode from runner definition
          local output_mode = runner.output or "inline"

          if output_mode == "split" then
            -- JSON prettification options (not yet implemented):
            -- 1. Pipe through `jq .` if available: cmd .. " | jq ."
            -- 2. Use vim.json.decode + vim.json.encode(data, {indent=2})
            -- 3. Set filetype of body portion to 'json' for treesitter highlighting
            -- 4. Use `python3 -m json.tool` as fallback

            -- Create or reuse a scratch buffer for this filetype
            local ft = vim.bo[bufid].filetype or "output"

            -- Use module-level tracking to avoid E95 buffer name conflict
            local scratch_bufnr = M._scratch_buffers[ft]

            -- Validate it still exists
            if scratch_bufnr and not vim.api.nvim_buf_is_valid(scratch_bufnr) then
              scratch_bufnr = nil
              M._scratch_buffers[ft] = nil
            end

            if not scratch_bufnr then
              scratch_bufnr = vim.api.nvim_create_buf(false, true)
              M._scratch_buffers[ft] = scratch_bufnr
            end

            -- Set buffer options
            vim.bo[scratch_bufnr].buftype = "nofile"
            vim.bo[scratch_bufnr].swapfile = false
            vim.bo[scratch_bufnr].buflisted = false
            vim.bo[scratch_bufnr].filetype = "http"

            -- Bind q to close buffer + window
            vim.api.nvim_buf_set_keymap(scratch_bufnr, 'n', 'q', '<cmd>bdelete<cr>', {
              noremap = true, silent = true, desc = "Close HTTP response buffer"
            })

            -- For HTTP split output: move timing footer to prelude
            if ft == "http" then
              local lines_list = vim.split(return_text, "\n")
              local timing_line = nil
              local timing_idx = nil
              -- Find the timing line (last line matching pattern)
              for i = #lines_list, 1, -1 do
                if lines_list[i]:match("^%-%-%- %d+ |") then
                  timing_line = lines_list[i]
                  timing_idx = i
                  break
                end
              end
              if timing_line and timing_idx then
                table.remove(lines_list, timing_idx)
                -- Build prelude: timing + separator + response
                local prelude = { timing_line, string.rep("-", 40) }
                -- Remove leading empty lines from response
                while #lines_list > 0 and lines_list[1] == "" do
                  table.remove(lines_list, 1)
                end
                for i = #prelude, 1, -1 do
                  table.insert(lines_list, 1, prelude[i])
                end
                return_text = table.concat(lines_list, "\n")
              end
            end

            -- Clear and write content
            vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, vim.split(return_text, "\n"))

            -- Ensure the buffer is visible in a split
            local scratch_win = nil
            for _, w in ipairs(vim.api.nvim_list_wins()) do
              if vim.api.nvim_win_get_buf(w) == scratch_bufnr then
                scratch_win = w
                break
              end
            end

            if not scratch_win then
              vim.cmd("botright vsplit")
              scratch_win = vim.api.nvim_get_current_win()
              vim.api.nvim_win_set_buf(scratch_win, scratch_bufnr)
            end

            -- Move cursor to top of the response
            vim.api.nvim_win_set_cursor(scratch_win, { 1, 0 })

            -- Return focus to the original window
            if vim.api.nvim_win_is_valid(winid) then
              vim.api.nvim_set_current_win(winid)
            end
          else
          -- Inline output mode (original behavior)
          local target_bufid = bufid
          local target_winid = winid
          local buf_valid = vim.api.nvim_buf_is_valid(target_bufid)
          local win_valid = vim.api.nvim_win_is_valid(target_winid)

          if not buf_valid then
            -- Original buffer was closed — create a new scratch buffer
            target_bufid = vim.api.nvim_create_buf(true, true)
            vim.api.nvim_set_current_buf(target_bufid)
            target_winid = vim.api.nvim_get_current_win()
            vim.notify(
              "原 buffer 已关闭，结果写入新 buffer",
              vim.log.levels.WARN
            )
          elseif not win_valid then
            -- Buffer is valid but window is gone — open buffer in current window
            target_winid = vim.api.nvim_get_current_win()
            vim.notify(
              "原 window 已关闭，结果写入当前 window",
              vim.log.levels.WARN
            )
          end

          -- Set the undo checkpoint for quick undo
          vim.cmd([[ let &ul=&ul ]])

          -- Insert at the cursor position
          local pos = {}
          if vim.api.nvim_get_current_buf() ~= target_bufid then
            vim.notify("script_runner finished in another buf.", vim.log.levels.INFO)
            pos = vim.api.nvim_buf_get_mark(target_bufid, '"')
          else
            if vim.api.nvim_win_is_valid(target_winid) then
              pos = vim.api.nvim_win_get_cursor(target_winid)
            else
              pos = { vim.api.nvim_buf_line_count(target_bufid), 0 }
            end
          end
          vim.api.nvim_buf_set_lines(target_bufid, pos[1], pos[1], false, vim.split(return_text, "\n"))
          end -- split/inline output mode
        end
      end)
    )

    if not ok then
      vim.notify(string.format("runner function returned error: %s", job_or_err), vim.log.levels.INFO)
      return
    end

    M._current_runner = job_or_err.pid

    -- Kill on timeout
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
