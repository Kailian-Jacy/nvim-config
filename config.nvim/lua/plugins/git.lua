return {
  {
    "mhinz/vim-signify",
    enabled = vim.g.modules.svn and vim.g.modules.svn.enabled,
    config = function()
      vim.cmd([[ set updatetime=100 ]])
    end,
  },
  {
    "linrongbin16/gitlinker.nvim",
    config = function ()
      require("gitlinker").setup({
        router = {
          browse = {
            ["^gitlab%.deepseek%.com"] = require('gitlinker.routers').gitlab_browse,
          },
          blame = {
            ["^gitlab%.deepseek%.com"] = require('gitlinker.routers').gitlab_blame,
          },
        }
      })
    end
  },
  {
    "lewis6991/gitsigns.nvim",
    cmd = {
      -- Refer to doc for more details:
      -- :h gitsigns-revision
      -- :h change_base
      "Gitsigns change_base"
    },
    keys = {
      {
        "<leader>hr",
        "<Cmd>Gitsigns reset_hunk<CR>",
        mode = "n",
      },
      {
        "<leader>hp",
        "<Cmd>Gitsigns preview_hunk_inline<CR>",
        mode = "n",
        desc = "n",
      },
      {
        "<leader>hq",
        "<Cmd>Gitsigns setqflist target=attached<CR>",
        mode = "n",
        desc = "n",
      },
      {
        "<leader>hQ",
        "<Cmd>Gitsigns setqflist target=all<CR>",
        mode = "n",
        desc = "n",
      },
      {
        "<leader>sd",
        function()
          -- Close the tabpage if it is already open.
          local orig_tabnr = vim.fn.tabpagenr()
          local name = vim.fn.gettabvar(orig_tabnr, "tabname")
          if name == "GitDiff" then
            vim.cmd("tabclose")
            return
          end
          -- Open new one for diffing
          local bufid = vim.api.nvim_get_current_buf()
          vim.cmd("tabnew")
          local tabnr = vim.fn.tabpagenr()
          vim.api.nvim_set_current_buf(bufid)
          vim.fn.settabvar(tabnr, "tabname", "GitDiff")
          require("gitsigns").diffthis()
        end,
        mode = "n",
        desc = "diff in a new tabpage",
      },
      {
        "<leader>hs",
        "<Cmd>Gitsigns stage_hunk<CR>",
        mode = "n",
        desc = "n",
      },
      {
        "<leader>hb",
        "<Cmd>Gitsigns blame_line<cr>",
        mode = "",
        desc = "toggle git blame",
      },
      {
        "<leader>hB",
        "<Cmd>Gitsigns blame<cr>",
        mode = "",
        desc = "toggle git blame",
      },
      {
        "]c",
        function()
          if vim.wo.diff then
            vim.cmd.normal({ ']c', bang = true })
          else
            require('gitsigns').nav_hunk('next')
          end
        end,
        mode = "n",
        desc = "next change",
      },
      {
        "[c",
        function()
          if vim.wo.diff then
            vim.cmd.normal({ '[c', bang = true })
          else
            require('gitsigns').nav_hunk('prev')
          end
        end,
        mode = "n",
        desc = "next change",
      },
    },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "┃" },
          change = { text = "┃" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
        numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
        linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
        word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir = {
          follow_files = true,
        },
        auto_attach = true,
        attach_to_untracked = false,
        current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
          delay = 1000,
          ignore_whitespace = false,
          virt_text_priority = 100,
        },
        current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil, -- Use default
        max_file_length = 40000, -- Disable if file is longer than this (in lines)
        preview_config = {
          -- Options passed to nvim_open_win
          border = "single",
          style = "minimal",
          relative = "cursor",
          row = 0,
          col = 1,
        },
      })
    end,
  },
  {
    -- Give diff tab to nvim.
    -- DiffviewOpen oldCommit..newCommit to perform diff. Left is old, and right is new.
    "sindrets/diffview.nvim",
    keys = {
      {
        "<leader>sD",
        "<Cmd>DiffviewOpen<CR>",
        mode = "n",
        desc = "n",
      },
    },
    event = "VeryLazy",
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        view = {
          merge_tool = {
            layout = "diff1_plain", -- or diff3_mixed.
          },
        },
        keymaps = {
          view = {
            { "n", "<leader>qj", actions.select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<leader>qk", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
            { "n", "<leader>sD", "<Cmd>tabclose<CR>",       mode = "n",                                      desc = "Close in diffview" },
            { "n", "<leader>fe", actions.toggle_files,      { desc = "Toggle the file panel." } },
          },
          file_panel = {
            { "n", "<leader>sD", "<Cmd>tabclose<CR>",  mode = "n",                         desc = "Close in diffview" },
            { "n", "<leader>fe", actions.toggle_files, { desc = "Toggle the file panel." } },
          }
        },
        hooks = {
          view_opened = function(view)
            -- 1. Get the current tabpage.
            local tab_id = view.tabpage
            -- 2. Set the name to be diff with versions.
            local workdir = vim.fn.getcwd(vim.fn.tabpagewinnr(tab_id), tab_id)
            -- TODO: Get the compared commit to display.
            vim.api.nvim_tabpage_set_var(tab_id, "tabname", "Diff: " .. vim.fn.fnamemodify(workdir, ":t"))
          end
        }
      })
    end
  },
  --{
  --"tpope/vim-fugitive",
  --},
}
