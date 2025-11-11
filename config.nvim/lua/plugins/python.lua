return {
  -- Before debugging, if anything happens,
  -- 1. Make sure python is reachable as `python` in shell;
  -- 2. Make sure venv-selector could reach the python executalb;
  -- 3. Make sure path `.vscode/launch.json` if you want to use;
  -- 4. Make sure debugpy is installed and corresponded to python executable.
  {
    "linux-cultist/venv-selector.nvim",
    -- Only load on python files.
    lazy = true,
    ft = { "python" },
    -- event = "BufEnter *.py" ,
    dependencies = {
      "neovim/nvim-lspconfig",
      -- "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap-python",
    },
    -- Selector is not needed except wanting to point
    --  python intepreter manually.
    config = function()
      require("venv-selector").setup({
        stay_on_this_version = true,
        search = {
          anaconda_base = { comamnd = "/opt/homebrew/Caskroom/miniconda/base", type = "anaconda" },
          -- anaconda_envs_path = "/home/cado/.conda/envs",
          -- pipenv_path = "~/.venv",
        },
        -- options see: https://github.com/linux-cultist/venv-selector.nvim?tab=readme-ov-file#global-options-to-the-plugin
        options = {
          cached_venv_automatic_activation = true
        }
      })
    end,
  },
  {
    "lukas-reineke/cmp-under-comparator",
  },
  {
    "mfussenegger/nvim-dap-python",
    -- Only load on python files.
    lazy = true,
    ft = { "python" },
    dependencies = {
      "mfussenegger/nvim-dap",

      -- It's not dependent, since dap-python only works on top of `python`
      --   executable. selector just sets the executable alternatives.
      -- "linux-cultist/venv-selector.nvim",
    },
    config = function()
      -- Set debugpy only when

      -- Try to get default python path.
      if not vim.fn.executable("python") then
        vim.notify("Could not find python executable. Please select by :VenvSelect", vim.log.levels.ERROR)
        return
      end
      -- Setup
      -- It's following the link of `python`. So we use VenvSelect to modify.
      require("dap-python").setup("python")
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
