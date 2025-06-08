return {
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        "<leader>hr",
        "<Cmd>Gitsigns reset_hunk<CR>",
        mode = "n",
      },
      {
        "<leader>hR",
        "<Cmd>Gitsigns preview_buffer<CR>",
        mode = "n",
      },
      {
        "<leader>hp",
        "<Cmd>Gitsigns preview_hunk<CR>",
        mode = "n",
        desc = "n",
      },
      {
        "<leader>hs",
        "<Cmd>Gitsigns stage_hunk<CR>",
        mode = "n",
        desc = "n",
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
    event = "VeryLazy",
  }
  --{
  --"tpope/vim-fugitive",
  --},
}
