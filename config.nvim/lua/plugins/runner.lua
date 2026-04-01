-- nvim-runner plugin configuration
-- In Nix mode, nvim-runner is provided as a startupPlugin (already on rtp).
-- In non-Nix mode, it's loaded from the nvim-runner directory adjacent to config.nvim.
local is_nix = vim.g.nixCats ~= nil

return {
  {
    -- In Nix mode: plugin is already on rtp via nixCats startupPlugin.
    -- Use the name so lazy.nvim can match it for config() orchestration.
    -- In non-Nix mode: use dir= to load from the local repo.
    name = "nvim-runner",
    dir = (not is_nix) and (function()
      -- Resolve the real path of stdpath("config") to handle symlinks,
      -- then go up to the repo root to find nvim-runner/
      local config_dir = vim.fn.resolve(vim.fn.stdpath("config"))
      return vim.fn.fnamemodify(config_dir, ":h") .. "/nvim-runner"
    end)() or nil,
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
