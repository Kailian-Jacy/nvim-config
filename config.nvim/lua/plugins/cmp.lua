return {
  {
    "SergioRibera/cmp-dotenv",
  },
  {
    "hrsh7th/nvim-cmp",
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
        completion = {
          completeopt = "menu,menuone,noinsert,noselect",
        },
        window = {
          completion = {
            border = "rounded",
            winhighlight = "Normal:Pmenu,FloatBorder:CompeDocumentationBorder",
            winblend = 0,
          },
          documentation = {
            border = "rounded",
            winhighlight = "Normal:Pmenu,FloatBorder:CompeDocumentationBorder",
            winblend = 0,
          },
        },
        -- Docs has example about how to set for copilot compatibility:
        mapping = cmp.mapping.preset.insert({
          -- Tab will only be used to expand when item being selected. Else you can be sure to tab expand snippets.
          ["<Tab>"] = function(_)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })
            elseif luasnip.expandable() then
              luasnip.expand()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              vim.api.nvim_feedkeys(
                vim.fn["copilot#Accept"](vim.api.nvim_replace_termcodes("<Tab>", true, true, true)),
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
          -- aligned with nvim screen shift and telescope previews shift. TODO: Not warking now.
          ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
          ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
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
          ["<Up>"] = function(_)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Previous"](), "n", true)
            end
          end,
          ["<C-j>"] = function(_)
            if cmp.visible() then
              cmp.select_next_item()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Next"](), "n", true)
            end
          end,
          ["<C-k>"] = function(_)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              vim.api.nvim_feedkeys(vim.fn["copilot#Previous"](), "n", true)
            end
          end,
        }),
        experimental = {
          ghost_text = false, -- this feature conflict with copilot.vim's preview.
        },
        sources = {
          { name = "luasnip" },
          {
            name = "cmp_tabnine",
            group_index = 1,
          },
          {
            name = "nvim_lsp",
          },
          { name = "buffer" },
          { name = "nvim_lua" },
          { name = "path" },
          {
            name = "dotenv",
            -- Defaults
            option = {
              path = vim.g.dotenv_dir,
              load_shell = true,
              item_kind = cmp.lsp.CompletionItemKind.Variable,
              eval_on_confirm = false,
              show_documentation = true,
              show_content_on_docs = true,
              documentation_kind = "markdown",
              dotenv_environment = ".*",
              file_priority = function(a, b)
                -- Prioritizing local files
                return a:upper() < b:upper()
              end,
            },
          },
        },
        sorting = {
          priority_weight = 100,
          comparators = {
            cmp.config.compare.offset,
            cmp.config.compare.exact,
            cmp.config.compare.score,
            cmp.config.compare.recently_used,
            require("cmp-under-comparator").under,
            cmp.config.compare.kind,
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
        -- mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })
      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(":", {
        -- mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
    end,
  },
}
