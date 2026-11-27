-- Custom Snacks pickers extracted from autocmds.lua

-- Snippet picker
vim.api.nvim_create_user_command("SnipPick", function()
  Snacks.picker.pick({
    supports_live = false,
    title = "Code Snippets",
    preview = "preview",
    format = function(item)
      return {
        { item.trigger, "Special" },
        { item.name, item.ft == "" and "Conceal" or "DiagnosticWarn" },
        { item.description },
      }
    end,
    finder = function()
      local snippets = {}
      for _, snip in ipairs(require("luasnip").get_snippets().all) do
        snip.ft = ""
        table.insert(snippets, snip)
      end
      for _, snip in ipairs(require("luasnip").get_snippets(vim.bo.ft)) do
        snip.ft = vim.bo.ft
        table.insert(snippets, snip)
      end
      local align_1 = 0
      for _, snip in pairs(snippets) do
        align_1 = math.max(align_1, #snip.name)
      end
      local align_2 = 0
      for _, snip in pairs(snippets) do
        align_2 = math.max(align_2, #snip.trigger)
      end
      local items = {}
      for _, snip in pairs(snippets) do
        local docstring = snip:get_docstring()
        if type(docstring) == "table" then
          docstring = table.concat(docstring)
        end
        local name = Snacks.picker.util.align(snip.name, align_1 + 3)
        local trigger = Snacks.picker.util.align(snip.trigger, align_2 + 3)
        local description = table.concat(snip.description)
        description = name == description and "" or description
        table.insert(items, {
          text = name .. description,
          name = name,
          description = description,
          trigger = trigger,
          orig_snip = snip,
          ft = snip.ft,
          preview = {
            ft = "json",
            text = docstring,
          },
        })
      end
      return items
    end,
    confirm = function(picker, item)
      picker:close()
      vim.fn.setreg('"', item.trigger)
    end,
  })
end, { desc = "Snacks picker for luasnip." })

-- Old files picker
local snack_old_file = function()
  local title = "OldFiles"
  return function()
    Snacks.picker.pick({
      global = false,
      toggles = {
        global = "g",
      },
      title = title,
      format = function(item, picker)
        local ret = require("snacks.picker.format").filename(item, picker)
        return ret
      end,
      finder = function(picker, _)
        local cwd = vim.fs.normalize(vim.fn.getcwd())
        local oldfile_items = vim.v.oldfiles
        if #oldfile_items == 0 then
          vim.print_silent("Oldfiles picker: No old files.")
          return {}
        end

        local tbl = {}
        for _, oldfile in ipairs(oldfile_items) do
          local full_path = vim.fs.normalize(oldfile)
          if not picker.global and full_path:find(cwd, 1, true) ~= 1 then
            goto continue
          end
          if oldfile:find("^term:/") or oldfile:find("^scp:/") or oldfile:find("^rsync:/") then
            goto continue
          end
          table.insert(tbl, {
            text = vim.fn.fnamemodify(oldfile, ":p:t"),
            _path = oldfile,
            file = oldfile,
          })
          ::continue::
        end
        return tbl
      end,
      actions = {
        toggle_local = function(picker)
          picker.opts.global = not picker.opts.global
          picker:find()
        end,
      },
      win = {
        input = {
          keys = {
            ["<c-g>"] = { "toggle_local", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            ["<c-g>"] = { "toggle_local", mode = { "n", "i" } },
          },
        },
      },
    })
  end
end

vim.api.nvim_create_user_command("SnackOldfiles", snack_old_file(), { desc = "Open oldfiles." })

