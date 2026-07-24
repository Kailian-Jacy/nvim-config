-- nvim-runner plugin configuration
-- The plugin is loaded from the nvim-runner directory adjacent to config.nvim
-- in the nvim-config repository. To use from a separate repo, change `dir` below
-- to the appropriate path or replace with a GitHub URL.
return {
  {
    dir = (function()
      -- Resolve the real path of stdpath("config") to handle symlinks,
      -- then go up to the repo root to find nvim-runner/
      local config_dir = vim.fn.resolve(vim.fn.stdpath("config"))
      return vim.fn.fnamemodify(config_dir, ":h") .. "/nvim-runner"
    end)(),
    config = function()
      require("nvim-runner").setup({
        -- Use defaults: python, lua, sh, nu runners
        -- timeout = 3000 (ms)
        -- insert_result = true
        keymaps = {
          run = { "<c-s-cr>", "<d-s-cr>" },
        },
      })
    end,
  },
}
