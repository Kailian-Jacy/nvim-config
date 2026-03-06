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

  -- Set up keymaps
  local keymaps = config.options.keymaps
  if keymaps and keymaps.run then
    local keys = keymaps.run
    if type(keys) == "string" then
      keys = { keys }
    end
    for _, key in ipairs(keys) do
      vim.keymap.set({ "n", "v" }, key, "<cmd>RunScript<CR>", { desc = "run current script" })
    end
  end
end

return M
