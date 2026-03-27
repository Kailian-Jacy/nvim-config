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

-- Bookmark pickers
vim.api.nvim_create_user_command("BookmarkGrepMarkedFiles", function()
  local Repo = require("bookmarks.domain.repo")
  local Node = require("bookmarks.domain.node")
  local active_list = Repo.ensure_and_get_active_list()
  local bookmarks = Node.get_all_bookmarks(active_list)

  local files = {}
  local seen = {}
  for _, bookmark in ipairs(bookmarks) do
    if not seen[bookmark.location.path] then
      seen[bookmark.location.path] = true
      table.insert(files, bookmark.location.path)
    end
  end

  local search_content = ""
  if vim.tbl_contains({ "v", "V", "s" }, vim.fn.mode()) then
    search_content = vim.g.function_get_selected_content()
  end

  Snacks.picker.grep({
    title = "Grep Bookmarked Files",
    dirs = files,
    hidden = true,
    search = search_content,
  })
end, { desc = "Remove the bookmark at cursor line.", nargs = "?" })

vim.api.nvim_create_user_command("BookmarkSnackPicker", function()
  Snacks.picker.pick({
    title = "Bookmarks",
    format = function(item, picker)
      local ret = require("snacks.picker.format").filename(item, picker)
      ret[#ret + 1] = { item.text }
      return ret
    end,
    finder = function(_, _)
      local bookmark_items = require("bookmarks.domain.node").get_all_bookmarks(
        require("bookmarks.domain.repo").ensure_and_get_active_list()
      )
      local tbl = {}
      for _, bookmark in ipairs(bookmark_items) do
        table.insert(tbl, {
          text = bookmark.name,
          _path = bookmark.location.path,
          _bookmark = bookmark,
          pos = { bookmark.location.line, bookmark.location.col },
          bm_location = bookmark.location,
          file = bookmark.location.path,
        })
      end
      return tbl
    end,
    actions = {
      delete_from_bookmarks = function(picker, item)
        local delete_from_bookmark = function(local_picker, local_item)
          local location = local_item.bm_location
          local node = require("bookmarks.domain.repo").find_node_by_location(location)
          if not node then
            vim.notify("No node found at cursor position", vim.log.levels.WARN)
            return
          end
          require("bookmarks.domain.service").delete_node(node.id)
          require("bookmarks.sign").safe_refresh_signs()
          local_picker.list:set_selected()
          local_picker.list:set_target()
          local_picker:find()
        end
        local sel = picker:selected()
        local items = #sel > 0 and sel or { item }
        for _, item in pairs(items) do
          delete_from_bookmark(picker, item)
        end
      end,
      edit_bookmark = function(picker, item)
        local text = "Original text name"
        vim.ui.input({
          prompt = "Edit Bookmark Name",
          default = text,
        }, function(value)
          vim.print(value)
          if not value then
            vim.print("Bookmark unchanged.")
            return
          end
          if value and (#value == 0 or value == text) then
            vim.print("Bookmark unchanged.")
            return
          end
          item._bookmark.name = value
          require("bookmarks.domain.service").rename_node(item._bookmark.id, value)
          picker.list:set_selected()
          picker.list:set_target()
          picker:find()
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<d-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<c-e>"] = { "edit_bookmark", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<c-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["<d-bs>"] = { "delete_from_bookmarks", mode = { "n", "i" } },
          ["dd"] = { "delete_from_bookmarks", mode = { "n" } },
          ["<c-e>"] = { "edit_bookmark", mode = { "n", "i" } },
          ["ee"] = { "edit_bookmark", mode = { "n" } },
        },
      },
    },
  })
end, { desc = "Bookmark table in snacks.picker" })
