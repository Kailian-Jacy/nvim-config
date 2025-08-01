return {
  -- {
  --   "SergioRibera/cmp-dotenv",
  -- },
  {
    "hrsh7th/cmp-nvim-lsp",
  },
  {
    "onsails/lspkind.nvim",
  },
  {
    "tzachar/cmp-tabnine",
    build = "./install.sh",
    dependencies = "hrsh7th/nvim-cmp",
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp" },
      -- LuaSnip
      { "L3MON4D3/LuaSnip", build = "make install_jsregexp", lazy = true },
      { "saadparwaiz1/cmp_luasnip", lazy = true },
      -- Cmdline
      { "hrsh7th/cmp-cmdline" },
      { "dmitmel/cmp-cmdline-history", lazy = true },
      -- Path
      { "FelipeLema/cmp-async-path", lazy = true },
      { "hrsh7th/cmp-nvim-lsp-signature-help" },
      { "chrisgrieser/cmp_yanky" },
      -- any keymap involving tab should be done before this plugin loaded.
      { "vidocqh/auto-indent.nvim" },
      { "hrsh7th/cmp-buffer" },
      { "hrsh7th/cmp-git" },
      { "hrsh7th/cmp-path" },
    },
    config = function()
      --[[local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nv(0))
        return col ~= 0 and
          vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
      end]]
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("cmp").setup({
        auto_brackets = {}, -- disabled. Being managed by other plugins.
        preselect = "none",
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 })(entry, vim_item)
            local strings = vim.split(kind.kind, "%s", { trimempty = true })
            kind.kind = " " .. (strings[1] or "") .. " "
            kind.menu = "    (" .. (strings[2] or "") .. ")"

            return kind
          end,
        },
        completion = {
          completeopt = "menu,menuone,noinsert,noselect",
        },
        window = {
          completion = {
            border = "rounded",
            winhighlight = "Normal:Pmenu,FloatBorder:CompeDocumentationBorder,CursorLine:PmenuSel,Search:Visual",
            winblend = 0,
          },
          documentation = {
            border = "rounded",
            winhighlight = "Normal:Pmenu,FloatBorder:CompeDocumentationBorder,CursorLine:PmenuSel,Search:Visual",
            winblend = 0,
          },
        },
        -- Docs has example about how to set for copilot compatibility:
        mapping = cmp.mapping.preset.insert({
          -- Tab will only be used to expand when item being selected. Else you can be sure to tab expand snippets.
          ["<Tab>"] = function(fallback)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })
            elseif luasnip.expandable() then
              luasnip.expand()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              vim.api.nvim_feedkeys(
                vim.fn["copilot#Accept"](function()
                  fallback()
                  -- As we are using auto-indent, \t don't need to be fed.
                  if vim.g._auto_indent_used == true then
                    return ""
                  else
                    return vim.api.nvim_replace_termcodes("\t", true, true, true) -- should be "n" mode to break infinite loop.
                  end
                end),
                "n",
                true
              )
            end
          end,
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end),
          -- aligned with nvim screen shift and telescope previews shift.
          -- TODO: Not warking now.
          ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "v", "n" }),
          ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "v", "n" }),
          -- cancel suggestion.
          ["<C-c>"] = function(_)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.abort()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Clear"](), "n", true)
            end
          end,
          ["<CR>"] = function(fallback)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm()
            else
              -- allow <CR> passthrough as normal line switching.
              fallback()
            end
          end,
          -- it's very rare to require copilot to give multiple solutions. If it's not good enough, we'll use avante to generate ai response manually.
          ["<Up>"] = function(_)
            if cmp.visible() then
              -- FIXME: Don't know how it works.. cmp.select_prev_item() is returning a function to be called... Anyway let's not change since runnable...
              cmp.select_prev_item()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Previous"](), "n", true)
            end
          end,
          ["<Down>"] = function(_)
            if cmp.visible() then
              cmp.select_next_item()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Next"](), "n", true)
            end
          end,
          ["<Right>"] = function(_)
            if luasnip.locally_jumpable() then
              luasnip.jump(1)
            else
              vim.api.nvim_feedkeys(
                vim.fn["copilot#AcceptLine"](vim.api.nvim_replace_termcodes("<Right>", true, true, true)),
                "n",
                true
              )
            end
          end,
          ["<Left>"] = cmp.mapping(function(fallback)
            if luasnip.locally_jumpable() then
              luasnip.jump(-1)
            else
              fallback()
            end
          end),
        }),
        experimental = {
          ghost_text = false, -- this feature conflict with copilot.vim's preview.
        },
        -- Sources are from groups:
        -- 1. High priority: Snips under certain conditions. Small group, rare: LuaSnip, Path.
        -- 2. Main stream: LSP related code information. Function, fields, rank by reference distance.
        -- 3. Low priority: From other possible contents. Text, yanked text. Env var.
        sources = cmp.config.sources({
          {
            name = "luasnip",
            priority = 150,
            option = {
              show_autosnippets = true,
              use_show_condition = false,
            },
          },
          {
            name = "async_path",
            priority = 150,
          },
          {
            name = "nvim_lsp",
            priority = 150,
          },
          {
            name = "nvim_lsp_signature_help",
            priority = 150,
            group_index = 1,
          },
          {
            name = "cmp_yanky",
            priority = 130,
            option = {
              minLength = 3,
              onlyCurrentFiletype = false,
            },
          },
          {
            name = "buffer",
            priority = 120,
          },
          {
            name = "nvim_lua",
            entry_filter = function()
              if vim.bo.filetype ~= "lua" then
                return false
              end
              return true
            end,
            priority = 110,
            group_index = 1,
          },
          -- Temporarily removing dotenv.
          -- It's rarely used, and introducing many rubbish envvar.
          -- Being marked as variable type makes them enjoying lsp level priority.
          -- And it has something to do with matching logic. 
          -- {
          --   name = "dotenv",
          --   priority = 20,
          --   -- Defaults
          --   option = {
          --     path = vim.g.dotenv_dir,
          --     load_shell = true,
          --     item_kind = cmp.lsp.CompletionItemKind.Variable,
          --     eval_on_confirm = false,
          --     show_documentation = true,
          --     show_content_on_docs = true,
          --     documentation_kind = "markdown",
          --     dotenv_environment = ".*",
          --     file_priority = function(a, b)
          --       -- Prioritizing local files
          --       return a:upper() < b:upper()
          --     end,
          --   },
          -- },
          {
            name = "cmp_tabnine",
            priority = 90,
          },
          {
            max_item_count = 7,
          },
        }),
        sorting = {
          priority_weight = 2,
          comparators = {
            cmp.config.compare.recently_used,
            cmp.config.compare.kind,
            cmp.config.compare.locality,
            cmp.config.compare.score,
            cmp.config.compare.exact,
            cmp.config.compare.offset,
            require("cmp-under-comparator").under,
          },
        },
        matching = {
          disallow_fuzzy_matching = false,
          disallow_fullfuzzy_matching = false,
          disallow_partial_fuzzy_matching = false,
          disallow_partial_matching = false,
          disallow_prefix_unmatching = false,
          disallow_symbol_nonprefix_matching = false,
        },
      })
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline({
          ["<Down>"] = {
            c = function(fallback)
              cmp.mapping.select_next_item({
                behavior = cmp.SelectBehavior.Insert,
              })(fallback)
            end,
          },
          ["<Up>"] = {
            c = function(fallback)
              cmp.mapping.select_prev_item({
                behavior = cmp.SelectBehavior.Insert,
              })(fallback)
            end,
          },
          ["<CR>"] = {
            c = function(fallback)
              if cmp.visible() and cmp.get_selected_entry() then
                cmp.confirm()
              else
                -- allow <CR> passthrough as normal line switching.
                fallback()
              end
            end,
          },
        }),
        --[[mapping = cmp.mapping.preset.cmdline({
          ["<Up>"] = function(fallback)

            vim.print("Up")
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end,
          ["<Down>"] = function(fallback)
            vim.print("Down")
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end,
        }),]]
        sources = {
          { name = "buffer", max_item_count = 7 },
        },
      })
      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline({
          ["<Down>"] = {
            c = function(fallback)
              cmp.mapping.select_next_item({
                behavior = cmp.SelectBehavior.Insert,
              })(fallback)
            end,
          },
          ["<Up>"] = {
            c = function(fallback)
              cmp.mapping.select_prev_item({
                behavior = cmp.SelectBehavior.Insert,
              })(fallback)
            end,
          },
          ["<CR>"] = {
            c = function(fallback)
              if cmp.visible() and cmp.get_selected_entry() then
                cmp.confirm()
              else
                -- allow <CR> passthrough as normal line switching.
                fallback()
              end
            end,
          },
        }),
        --[[mapping = cmp.mapping.preset.cmdline({
          ["<Up>"] = function(fallback)
            vim.print("Up")
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end,
          ["<Down>"] = function(fallback)
            vim.print("Down")
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end,
        }),]]
        sources = cmp.config.sources({
          { name = "async_path", max_item_count = 7 },
          { name = "cmdline", max_item_count = 7 },
          { name = "cmdline_history", max_item_count = 7 },
          { name = "buffer", max_item_count = 7 }, -- used for replacement
        }),
      })
    end,
  },
}
