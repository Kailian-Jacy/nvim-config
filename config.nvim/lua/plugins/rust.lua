return {
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      opts.server = opts.server or {}
      opts.server.settings = opts.server.settings or {}
      opts.server.settings["rust-analyzer"] = opts.server.settings["rust-analyzer"] or {}
      opts.server.settings["rust-analyzer"].procMacro = { enable = true }
      -- opts.server.settings["rust-analyzer"].diagnostics = {
      --   enable = true,
      --   disabled = { "unresolved-proc-macro", "unresolved-macro-call" },
      --   enableExperimental = true,
      -- }
    end,
  },
}
