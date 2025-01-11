return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        extensions = {
          file_browser = {
            theme = "ivy",
            -- disables netrw and use telescope-file-browser in its place
            hijack_netrw = true,
            --mappings = {
            --["i"] = {
            ---- your custom insert mode mappings
            --},
            --["n"] = {
            ---- your custom normal mode mappings
            --},
            --},
          },
        },
        require("telescope").load_extension("file_browser"),
      })
    end,
  },
  {
    "jvgrootveld/telescope-zoxide",
    keys = {
      {
        "<leader>zz",
        function()
          require("telescope").extensions.zoxide.list()
        end,
        mode = "n",
        desc = "Switch working directory of current index",
      },
    },
    config = function()
      local t = require("telescope")
      local z_utils = require("telescope._extensions.zoxide.utils")

      notification = function(selection)
        print("Update to (" .. selection.z_score .. ") " .. selection.path)
      end

      -- Configure the extension
      t.setup({
        extensions = {
          zoxide = {
            prompt_title = "Navigating To",
            mappings = {
              default = {
                action = function(selection)
                  vim.cmd.lcd(selection.path)
                end,
                after_action = notification,
              },
              ["<C-CR>"] = {
                action = function(selection)
                  vim.cmd.cd(selection.path)
                end,
                after_action = notification,
              },
              ["<C-b>"] = {
                keepinsert = true,
                action = function(selection)
                  require("telescope").extensions.file_browser.file_browser({ cwd = selection.path })
                end,
              },
            },
          },
        },
      })

      -- Load the extension
      t.load_extension("zoxide")
    end,
  },
}
