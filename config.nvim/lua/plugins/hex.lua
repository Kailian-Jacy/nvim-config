return {
  {
    "RaafatTurki/hex.nvim",
    enabled = vim.g.read_binary_with_xxd or false,
    config = function()
      require("hex").setup()
    end,
  },
}
