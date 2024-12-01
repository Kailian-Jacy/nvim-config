return {
  {
    "linux-cultist/venv-selector.nvim",
    config = function()
      require("venv-selector").setup {
        settings = {
        search = {
          bare_envs = {
            command = "fd python$ ~/.venv/",
          },
        },
        },
      }
    end
  },
  {
    "lukas-reineke/cmp-under-comparator"
  }
}
