return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    keys = {
      {
        "<leader>ee",
        "<cmd>Telescope file_browser select_buffer=true<cr>",
        mode = "n",
      },
      {
        "<leader>eE",
        "<cmd>Telescope file_browser select_buffer=true no_ignore=true<cr>",
        mode = "n",
      },
      {
        "<leader>fe",
        "<cmd>Telescope file_browser path=%:p:h select_buffer=true<cr>",
        mode = "n",
      },
      {
        "<leader>fE",
        "<cmd>Telescope file_browser path=%:p:h select_buffer=true no_ignore=true<cr>",
        mode = "n",
      },
    },
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
              ["<D-CR>"] = {
                action = function(selection)
                  vim.cmd.cd(selection.path)
                end,
                after_action = notification,
              },
              ["<C-CR>"] = {
                action = function(selection)
                  vim.cmd.cd(selection.path)
                end,
                after_action = notification,
              },
              -- create new tab and start there.
              ["<c-t>"] = {
                action = function(selection)
                  vim.cmd[[ tabnew ]]
                  vim.cmd.tcd(selection.path)
                end,
                after_action = notification,
              },
              ["<C-x>"] = {
                action = function(selection)
                  vim.cmd[[ split ]]
                  vim.cmd.lcd(selection.path)
                end
              },
              ["<C-X>"] = {
                action = function(selection)
                  vim.cmd[[ vsplit ]]
                  vim.cmd.lcd(selection.path)
                end
              },
              ["<C-v>"] = {
                action = function(selection)
                  vim.cmd[[ vsplit ]]
                  vim.cmd.lcd(selection.path)
                end
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
