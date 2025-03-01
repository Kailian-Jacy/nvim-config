return {
  {
    "mrcjkb/rustaceanvim",
    version = "^5", -- Recommended
    lazy = false, -- This plugin is already lazy
    config = function()
      vim.g.rustaceanvim = {
        server = {
          setting = {
            ["rust-analyzer"] = {
              procMacro = { enabled = true },
            },
          },
        },
      }
      -- vim.g.rustaceanvim.server.settings["rust-analyzer"].diagnostics = {
      --   enable = true,
      --   disabled = { "unresolved-proc-macro", "unresolved-macro-call" },
      --   enableExperimental = true,
      -- }
    end,
  },
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup({})
    end,
  },
}
