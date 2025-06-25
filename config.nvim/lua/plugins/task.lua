return {
  {
    "stevearc/overseer.nvim",
    keys = {
      {
        "<leader>ll",
        "<cmd>OverseerQuickAction open float<cr>",
      },
      {
        "<leader>lL",
        "<cmd>OverseerToggle<cr>",
      },
      {
        "<leader>lm",
        "<cmd>OverseerRunCmd<cr>",
      },
      {
        "<leader>lr",
        "<cmd>OverseerRun<cr>",
      },
    },
    config = function()
      require("overseer").setup({
        -- TODO: Find some way to set for `_disposed_` and `on_complete_dispose`.
        task_list = {
          bindings = {
            ["<c-k>"] = "<c-w><c-k>",
            ["<c-j>"] = "<c-w><c-j>",
            ["<c-l>"] = "<c-w><c-l>",
            ["<c-h>"] = "<c-w><c-h>",
            ["<cr>"] = "TogglePreview",
            ["<c-cr>"] = "OpenFloat",
            ["<d-cr>"] = "OpenFloat",
            ["<c-s-r>"] = "OpenVsplit",
            ["a"] = "RunAction",
          },
          direction = "left",
        },
        task_editor = {
          bindings = {
            i = {
              ["<c-cr>"] = "Submit",
              ["<d-cr>"] = "Submit",
              ["<c-c>"] = "Cancel",
              ["<d-c>"] = "Cancel",
            },
            n = {
              ["<c-cr>"] = "Submit",
              ["<d-cr>"] = "Submit",
              ["<c-c>"] = "Cancel",
              ["<d-c>"] = "Cancel",
              ["<esc>"] = "Cancel",
            },
          },
        },
      })
      -- Setup autocmd.
      vim.api.nvim_create_user_command("TaskLoad", function()
        require("overseer").load_template("customized.customized")
      end, { desc = "Load task" })

      vim.api.nvim_create_user_command("TaskEdit", function()
        local path = vim.fn.stdpath("config") .. "/lua/overseer/template" .. "/customized/customized.lua"
        local template = [[
local overseer = require("overseer")
return {
  -- Required fields
  name = "Some Task",
  builder = function(params)
    -- This must return an overseer.TaskDefinition
    return {
      -- cmd is the only required field
      cmd = { "echo" },
      -- additional arguments for the cmd
      args = { "hello", "world" },
      -- the name of the task (defaults to the cmd of the task)
      name = "Greet",
      -- set the working directory for the task
      -- cwd = "/tmp",
      -- additional environment variables
      env = {
        VAR = "FOO",
      },
      -- the list of components or component aliases to add to the task
      -- components = { "my_custom_component", "default" },
      -- arbitrary table of data for your own personal use
      metadata = {
        foo = "bar",
      },
    }
  end,
  -- Optional fields
  desc = "Optional description of task",
  -- Tags can be used in overseer.run_template()
  tags = { overseer.TAG.BUILD },
  params = {
    -- See :help overseer-params
  },
  -- Determines sort order when choosing tasks. Lower comes first.
  priority = 50,
  -- Add requirements for this template. If they are not met, the template will not be visible.
  -- All fields are optional.
  -- condition = {
  --   -- A string or list of strings
  --   -- Only matches when current buffer is one of the listed filetypes
  --   filetype = { "c", "cpp" },
  --   -- A string or list of strings
  --   -- Only matches when cwd is inside one of the listed dirs
  --   dir = "/home/user/my_project",
  --   -- Arbitrary logic for determining if task is available
  --   callback = function(search)
  --     print(vim.inspect(search))
  --     return true
  --   end,
  -- },
}
        ]]
        if vim.fn.filereadable(path) == 0 then
          local dir = vim.fn.fnamemodify(path, ":h")
          vim.fn.mkdir(dir, "p") -- Create parent directories if they don't exist
          -- write template to the customized file.
          -- vim.fn.writefile(template, path)
          vim.print("No task template found. Creating at " .. path .. ".")
          vim.fn.writefile(vim.split(template, "\n"), path)
        end
        vim.cmd("e" .. path)
        vim.print("Call `TaskLoad` autocmd when finish edition.")
      end, { desc = "Open task configuration file" })
    end,
  },
}
