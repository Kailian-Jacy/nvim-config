-- Neoview — External renderer for Neovim (Tauri-based)
return {
  {
    "neoview",
    virtual = true,
    config = function()
      local this_file = debug.getinfo(1, "S").source:sub(2)
      local config_dir = vim.fn.fnamemodify(this_file, ":h:h:h")
      local project = vim.fn.resolve(config_dir .. "/../neoview")

      require("config.neoview").setup({
        markdown = {
          -- debug build for fast iteration; change to /release/ for final install
          bin = project .. "/target/debug/neoview",
          dir = project .. "/config",
          events = { "BufWritePost", "InsertLeave", "TextChanged" },
          -- Override specific CSS variables (optional):
          -- theme_overrides = {
          --   ["--bg"] = "#000000",
          --   ["--border"] = "#333333",
          -- },
        },
      })
    end,
  },
}
