return {
  {
    "jvgrootveld/telescope-zoxide",
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
                after_action = notification
              },
              ["<C-CR>"] = {
                action = function(selection)
                  vim.cmd.cd(selection.path)
                end,
                after_action = notification
              },
              ["<C-b>"] = {
                keepinsert = true,
                action = function(selection)
                  require("telescope").extensions.file_browser.file_browser({ cwd = selection.path })
                end
              },
            },
          },
        },
      })

      -- Load the extension
      t.load_extension('zoxide')

      -- Add a mapping
      vim.keymap.set("n", "<leader>zz", t.extensions.zoxide.list)
    end
  }
}
