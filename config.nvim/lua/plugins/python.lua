return {
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap-python",
    },
    -- Selector is not needed except wanting to point
    --  python intepreter manually.
    event = "VeryLazy",
    config = function()
      require("venv-selector").setup({
        stay_on_this_version = true,
        settings = {
          search = {
            bare_envs = {
              -- TODO: Search envs not precise.
              command = "fd python$ ~/.venv/",
            },
          },
        },
      })
      -- require("venv-selector").retrieve_from_cache() -- TODO: it's not working for now.
    end,
  },
  {
    "lukas-reineke/cmp-under-comparator",
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- Try to get default python path.
      if not vim.fn.executable("python") then
        vim.notify("Could not find python executable. Please select by :VenvSelect", vim.log.levels.ERROR)
        return
      end
      -- Setup
      -- It's following the link of `python`. So we use VenvSelect to modify.
      require("dap-python").setup("python")
      if vim.fn.executable("debugpy") == 0 then
        vim.notify(
          "Debugpy is not installed. Install with:\n"
            .. "mkdir -p ~/.virtualenvs\n"
            .. "cd ~/.virtualenvs\n"
            .. "python -m venv debugpy\n"
            .. "debugpy/bin/python -m pip install debugpy",
          vim.log.levels.ERROR
        )
        return
      end
      table.insert(require("dap").configurations.python, {
        type = "debugpy",
        request = "launch",
        name = "Debugpy: Default debug configuration",
        program = "${file}",
        stopOnEntry = true,
        console = "integratedTerminal",
      })
    end,
  },
}
