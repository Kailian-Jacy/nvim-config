-- nvim-runner/lua/nvim-runner/init.lua
-- Plugin entry point

local M = {}

--- Setup nvim-runner with user options
---@param opts? NvimRunnerConfig
function M.setup(opts)
  local config = require("nvim-runner.config")
  config.setup(opts)

  -- Create user commands
  vim.api.nvim_create_user_command("RunScript", function()
    require("nvim-runner.runner").run()
  end, {
    desc = "Run current script. Use vim.b.runner to customize buffer local runner.",
  })

  vim.api.nvim_create_user_command("RunTest", function()
    require("nvim-runner.test_runner").run()
  end, {
    desc = "Run *_vimtest.lua files in cwd",
  })

  vim.api.nvim_create_user_command("SetBufRunner", function(cmd_opts)
    local filetype = vim.bo.filetype
    local template = vim.trim(cmd_opts.args):gsub('^"(.-)"$', "%1")

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
      },
    })
  end, {
    desc = 'buffer runner. e.g: SetBufRunner echo -e | /usr/bin/python3 <<EOF\n${text}\nEOF\n',
    nargs = 1,
  })

  -- Create RunnerTimeout command
  vim.api.nvim_create_user_command("RunnerTimeout", function(cmd_opts)
    local ms = tonumber(cmd_opts.args)
    if not ms or ms <= 0 then
      vim.notify("RunnerTimeout: invalid timeout value (must be positive number in ms)", vim.log.levels.ERROR)
      return
    end
    if cmd_opts.bang then
      -- :RunnerTimeout! 5000 → set global timeout
      M.set_timeout(ms)
      vim.notify(string.format("Global runner timeout set to %d ms", ms), vim.log.levels.INFO)
    else
      -- :RunnerTimeout 5000 → set buffer-local timeout
      M.set_buf_timeout(0, ms)
      vim.notify(string.format("Buffer-local runner timeout set to %d ms", ms), vim.log.levels.INFO)
    end
  end, {
    desc = "Set runner timeout. :RunnerTimeout 5000 (buffer-local) | :RunnerTimeout! 5000 (global)",
    nargs = 1,
    bang = true,
  })

  -- Set up keymaps (delete old ones first to avoid duplication on re-setup)
  local keymaps = config.options.keymaps
  -- Remove previously registered keymaps
  if M._registered_keymaps then
    for _, key in ipairs(M._registered_keymaps) do
      pcall(vim.keymap.del, { "n", "v" }, key)
    end
  end
  M._registered_keymaps = {}

  if keymaps and keymaps.run then
    local keys = keymaps.run
    if type(keys) == "string" then
      keys = { keys }
    end
    for _, key in ipairs(keys) do
      vim.keymap.set({ "n", "v" }, key, "<cmd>RunScript<CR>", { desc = "run current script" })
      table.insert(M._registered_keymaps, key)
    end
  end
end

--- Set global default timeout (ms)
---@param ms number timeout in milliseconds
function M.set_timeout(ms)
  assert(type(ms) == "number" and ms > 0, "timeout must be a positive number (ms)")
  local config = require("nvim-runner.config")
  config.options.timeout = ms
end

--- Set buffer-local timeout (ms)
---@param bufnr number buffer number (0 for current)
---@param ms number timeout in milliseconds
function M.set_buf_timeout(bufnr, ms)
  assert(type(ms) == "number" and ms > 0, "timeout must be a positive number (ms)")
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  vim.b[bufnr].runner_timeout = ms
end

return M
