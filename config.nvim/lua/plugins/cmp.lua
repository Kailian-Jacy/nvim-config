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
      { "lukas-reineke/cmp-under-comparator" },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Smart comparator: boost items that are closer to the cursor (locality)
      -- and prefer items matching the current scope/context.
      local locality_bonus_comparator = function(entry1, entry2)
        -- Strongly prefer items from the same file/buffer over remote sources
        local source1 = entry1.source.name
        local source2 = entry2.source.name
        local local_sources = { nvim_lsp = true, luasnip = true, buffer = true, nvim_lsp_signature_help = true }

        local is_local1 = local_sources[source1] or false
        local is_local2 = local_sources[source2] or false

        if is_local1 and not is_local2 then
          return true
        elseif not is_local1 and is_local2 then
          return false
        end

        -- For LSP items, prefer items with smaller sort text (usually indicates proximity)
        -- and prefer variables/fields over keywords
        local kind1 = entry1:get_kind()
        local kind2 = entry2:get_kind()

        -- Variable and Field kinds are more relevant in most editing contexts
        local variable_kinds = {
          [cmp.lsp.CompletionItemKind.Variable] = true,
          [cmp.lsp.CompletionItemKind.Field] = true,
          [cmp.lsp.CompletionItemKind.Property] = true,
        }

        local is_var1 = variable_kinds[kind1] or false
        local is_var2 = variable_kinds[kind2] or false

        -- When one is a variable/field and the other is not, prefer the variable
        -- But only when both are from LSP
        if source1 == "nvim_lsp" and source2 == "nvim_lsp" then
          if is_var1 and not is_var2 then
            return true
          elseif not is_var1 and is_var2 then
            return false
          end
        end

        return nil -- Fall through to next comparator
      end

      -- Prefer items that start with the input (prefix match) over fuzzy matches.
      -- Uses live vim context (not entry context) to ensure strict weak ordering:
      -- entry1.context may differ from entry2.context when sources are isIncomplete
      -- (e.g. cmdline source), which would violate antisymmetry. (fix #52)
      local prefix_match_comparator = function(entry1, entry2)
        local cursor_before_line
        if vim.fn.mode() == "c" then
          local pos = vim.fn.getcmdpos()
          cursor_before_line = string.sub(vim.fn.getcmdline(), 1, pos - 1)
        else
          local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
          if not ok then
            return nil
          end
          cursor_before_line = string.sub(vim.api.nvim_get_current_line(), 1, cursor[2])
        end

        local input = cursor_before_line:match("[%w_]+$") or ""
        if #input == 0 then
          return nil
        end

        local word1 = entry1:get_filter_text() or entry1.completion_item.label or ""
        local word2 = entry2:get_filter_text() or entry2.completion_item.label or ""

        local prefix1 = vim.startswith(word1:lower(), input:lower())
        local prefix2 = vim.startswith(word2:lower(), input:lower())

        if prefix1 and not prefix2 then
          return true
        elseif not prefix1 and prefix2 then
          return false
        end

        return nil
      end

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
        -- Snippet configuration - ensure LuaSnip is properly connected
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
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
              fallback()
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
            priority = 160,
            option = {
              show_autosnippets = true,
              use_show_condition = true,
            },
          },
          {
            name = "async_path",
            priority = 155,
          },
          {
            name = "nvim_lsp",
            priority = 150,
            -- Filter out snippet items from LSP when LuaSnip can handle them,
            -- to avoid duplicate snippet entries.
            entry_filter = function(entry, _)
              local kind = entry:get_kind()
              -- Allow everything except Snippet kind from LSP when LuaSnip is active
              if kind == cmp.lsp.CompletionItemKind.Snippet then
                return false
              end
              return true
            end,
          },
          {
            name = "nvim_lsp_signature_help",
            priority = 150,
            group_index = 1,
          },
          {
            name = "cmp_yanky",
            priority = 100,
            option = {
              minLength = 3,
              onlyCurrentFiletype = false,
            },
          },
          {
            name = "buffer",
            priority = 90,
            option = {
              -- Only get completions from visible buffers to limit noise
              get_bufnrs = function()
                local bufs = {}
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                  bufs[vim.api.nvim_win_get_buf(win)] = true
                end
                return vim.tbl_keys(bufs)
              end,
            },
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
            max_item_count = 7,
          },
        }),
        sorting = {
          priority_weight = 2,
          comparators = {
            -- 1. Recently used items first
            cmp.config.compare.recently_used,
            -- 2. Prefer prefix matches over fuzzy
            prefix_match_comparator,
            -- 3. Exact matches
            cmp.config.compare.exact,
            -- 4. Locality-aware: prefer variables/fields, prefer local sources
            locality_bonus_comparator,
            -- 5. LSP-provided sort order
            cmp.config.compare.score,
            -- 6. Kind-based ordering (variables > functions > keywords)
            cmp.config.compare.kind,
            -- 7. Proximity in buffer
            cmp.config.compare.locality,
            -- 8. Offset-based ordering
            cmp.config.compare.offset,
            -- 9. Underscore items last
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
      -- Cmdline sorting: omit insert-mode-specific comparators (locality_bonus,
      -- prefix_match) that are unnecessary for cmdline and could cause issues
      -- with context inconsistency. (fix #52)
      local cmdline_sorting = {
        priority_weight = 2,
        comparators = {
          cmp.config.compare.recently_used,
          cmp.config.compare.exact,
          cmp.config.compare.score,
          cmp.config.compare.kind,
          cmp.config.compare.order,
        },
      }

      cmp.setup.cmdline({ "/", "?" }, {
        sorting = cmdline_sorting,
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
        sources = {
          { name = "buffer", max_item_count = 7 },
        },
      })
      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(":", {
        sorting = cmdline_sorting,
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
