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
    cmd = { "GitLink" },
    keys = {
      { "<leader>gl", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Copy git link" },
      { "<leader>gL", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Open git link in browser" },
    },
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
    lazy = false,
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
      -- Diff against merge base (Issue #13: diff current file against merge conflict base)
      {
        "<leader>sB",
        function()
          -- Detect merge/rebase state and diff current file against the merge base
          local merge_head = vim.fn.trim(vim.fn.system("git rev-parse MERGE_HEAD 2>/dev/null"))
          local rebase_head = vim.fn.trim(vim.fn.system("git rev-parse REBASE_HEAD 2>/dev/null"))
          local ref = merge_head ~= "" and merge_head or rebase_head
          if ref == "" then
            vim.notify("Not in a merge/rebase state. Use <leader>sA for arbitrary ref diff.", vim.log.levels.WARN)
            return
          end
          local merge_base = vim.fn.trim(vim.fn.system("git merge-base HEAD " .. ref .. " 2>/dev/null"))
          if merge_base == "" then
            vim.notify("Could not determine merge base.", vim.log.levels.ERROR)
            return
          end
          local short_hash = merge_base:sub(1, 8)
          local bufid = vim.api.nvim_get_current_buf()
          local cursor_pos = vim.api.nvim_win_get_cursor(0)
          vim.cmd("tabnew")
          local tabnr = vim.fn.tabpagenr()
          vim.api.nvim_set_current_buf(bufid)
          vim.fn.settabvar(tabnr, "tabname", "MergeBase: " .. short_hash)
          require("gitsigns").diffthis(merge_base)
          -- Restore cursor position
          pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
        end,
        mode = "n",
        desc = "Diff current file against merge base",
      },
      -- Diff against arbitrary ref (Issue #13)
      {
        "<leader>sA",
        function()
          vim.ui.input({ prompt = "Diff against ref: ", default = "HEAD~1" }, function(ref)
            if not ref or ref == "" then return end
            local resolved = vim.fn.trim(vim.fn.system("git rev-parse " .. ref .. " 2>/dev/null"))
            if resolved == "" or vim.v.shell_error ~= 0 then
              vim.notify("Invalid git ref: " .. ref, vim.log.levels.ERROR)
              return
            end
            local bufid = vim.api.nvim_get_current_buf()
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            vim.cmd("tabnew")
            local tabnr = vim.fn.tabpagenr()
            vim.api.nvim_set_current_buf(bufid)
            vim.fn.settabvar(tabnr, "tabname", "Diff: " .. ref)
            require("gitsigns").diffthis(resolved)
            pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
          end)
        end,
        mode = "n",
        desc = "Diff current file against any git ref",
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
      -- Git bar toggles (Issue #13: toggle of bars)
      {
        "<leader>ugs",
        "<Cmd>Gitsigns toggle_signs<CR>",
        mode = "n",
        desc = "Toggle git signs in sign column",
      },
      {
        "<leader>ugn",
        "<Cmd>Gitsigns toggle_numhl<CR>",
        mode = "n",
        desc = "Toggle number column git highlight",
      },
      {
        "<leader>ugl",
        "<Cmd>Gitsigns toggle_linehl<CR>",
        mode = "n",
        desc = "Toggle line highlight for changed lines",
      },
      {
        "<leader>ugw",
        "<Cmd>Gitsigns toggle_word_diff<CR>",
        mode = "n",
        desc = "Toggle inline word diff",
      },
      {
        "<leader>ugb",
        "<Cmd>Gitsigns toggle_current_line_blame<CR>",
        mode = "n",
        desc = "Toggle current line blame",
      },
      {
        "<leader>ugc",
        function()
          -- Cycle through git bar visibility levels
          local level = vim.g.gitsigns_bar_level or 0
          level = (level + 1) % 4
          vim.g.gitsigns_bar_level = level
          local gs = require("gitsigns")
          if level == 0 then
            -- Level 0: signs only (default)
            gs.toggle_signs(true)
            gs.toggle_numhl(false)
            gs.toggle_current_line_blame(false)
            gs.toggle_word_diff(false)
            vim.notify("Git bars: signs only", vim.log.levels.INFO)
          elseif level == 1 then
            -- Level 1: signs + numhl
            gs.toggle_signs(true)
            gs.toggle_numhl(true)
            gs.toggle_current_line_blame(false)
            gs.toggle_word_diff(false)
            vim.notify("Git bars: signs + numhl", vim.log.levels.INFO)
          elseif level == 2 then
            -- Level 2: signs + numhl + blame
            gs.toggle_signs(true)
            gs.toggle_numhl(true)
            gs.toggle_current_line_blame(true)
            gs.toggle_word_diff(false)
            vim.notify("Git bars: signs + numhl + blame", vim.log.levels.INFO)
          elseif level == 3 then
            -- Level 3: all off (clean view)
            gs.toggle_signs(false)
            gs.toggle_numhl(false)
            gs.toggle_current_line_blame(false)
            gs.toggle_word_diff(false)
            vim.notify("Git bars: all off", vim.log.levels.INFO)
          end
        end,
        mode = "n",
        desc = "Cycle git bar visibility levels",
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
    -- VSCode-style diff/merge viewer (replaces diffview.nvim).
    --   :CodeDiff              -> git status explorer (pick files to diff);
    --                            run again inside a diff tab to close it.
    --   :CodeDiff <revision>   -> diff working tree against a git revision.
    --   :CodeDiff history      -> commit history panel.
    --   :CodeDiff merge <file> -> 3-way merge conflict resolution.
    -- The plugin auto-downloads a prebuilt binary on first use.
    "esmuellert/codediff.nvim",
    cmd = { "CodeDiff" },
    keys = {
      {
        "<leader>sD",
        function()
          -- Capture the invoking tab's display name so the diff tab can be
          -- named "[diff]<original_tab_name>" once it opens (see config()).
          local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
          local in_diff = ok and lifecycle.get_session(vim.api.nvim_get_current_tabpage()) ~= nil
          if not in_diff and type(vim.g.tabname) == "function" then
            vim.g._codediff_origin_tabname = vim.g.tabname(vim.fn.tabpagenr())
          end
          vim.cmd("CodeDiff")
        end,
        mode = "n",
        -- :CodeDiff toggles: opens the explorer, or closes the diff tab when
        -- already inside one -- matching the old diffview <leader>sD behaviour.
        desc = "Toggle CodeDiff (git explorer)",
      },
    },
    opts = {
      diff = {
        -- @AI: inline by default
        layout = "side-by-side",
        original_position = "left", -- old/original on the left, like diffview
      },
      keymaps = {
        view = {
          toggle_explorer = "<leader>b", -- toggle the file panel
          next_file = "<Tab>",           -- switch to next diff file
          prev_file = "<S-Tab>",         -- switch to previous diff file
        },
        -- Conflict keymaps below already match the previous diffview bindings
        -- out of the box; they are set explicitly here for clarity:
        --   <leader>co accept_current (ours)    <leader>cO accept_all_current
        --   <leader>ct accept_incoming (theirs) <leader>cT accept_all_incoming
        --   <leader>cb accept_both
        --   <leader>cx discard (keep base)
        --   ]x / [x    next / prev conflict
        conflict = {
          accept_current = "<leader>co",
          accept_incoming = "<leader>ct",
          accept_both = "<leader>cb",
          discard = "<leader>cx",
          accept_all_current = "<leader>cO",
          accept_all_incoming = "<leader>cT",
          next_conflict = "]x",
          prev_conflict = "[x",
        },
      },
    },
    config = function(_, opts)
      require("codediff").setup(opts)

      -- Name the diff tabpage "[diff]<original_tab_name>" so the custom
      -- tabline (vim.g.tabname) shows where the diff came from. The origin
      -- name is captured by the <leader>sD keymap; for a bare :CodeDiff we
      -- fall back to the tab's working-directory tail.
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("CodeDiffTabName", { clear = true }),
        pattern = "CodeDiffOpen",
        callback = function(ev)
          local tabpage = ev.data and ev.data.tabpage
          if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
            return
          end
          local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
          local origin = vim.g._codediff_origin_tabname
          vim.g._codediff_origin_tabname = nil
          if not origin or origin == "" then
            local win = vim.fn.tabpagewinnr(tabnr)
            origin = vim.fn.fnamemodify(vim.fn.getcwd(win, tabnr), ":t")
          end
          vim.fn.settabvar(tabnr, "tabname", "[diff]" .. origin)
          vim.cmd("redrawtabline")
        end,
      })
    end,
  },
  --{
  --"tpope/vim-fugitive",
  --},
  {
    -- Virtual plugin for extended git workflow commands
    -- Complements gitsigns (hunk-level) and codediff (diff/merge) with
    -- higher-level git operations: stash, log, cherry-pick, and interactive staging.
    -- Addresses nvim-config#13: Scriptlize git informations for workflow.
    dir = vim.fn.stdpath("config"),
    name = "nvim-git-workflow",
    lazy = false,
    config = function()
      local function run(cmd)
        return vim.fn.trim(vim.fn.system(cmd .. " 2>/dev/null"))
      end

      local function in_git_repo()
        return run("git rev-parse --is-inside-work-tree") == "true"
      end

      -- ============================================================
      -- 1. Git stash management
      -- ============================================================
      vim.api.nvim_create_user_command("GitStash", function(opts)
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        local subcmd = opts.args
        if subcmd == "" or subcmd == "push" then
          vim.ui.input({ prompt = "Stash message (empty for default): " }, function(msg)
            if msg == nil then return end
            local cmd = "git stash push"
            if msg ~= "" then
              cmd = cmd .. " -m " .. vim.fn.shellescape(msg)
            end
            local result = run(cmd)
            vim.notify(result ~= "" and result or "Stashed.", vim.log.levels.INFO)
          end)
        elseif subcmd == "pop" then
          local result = run("git stash pop")
          vim.notify(result ~= "" and result or "Stash popped.", vim.log.levels.INFO)
          vim.cmd("checktime") -- reload changed files
        elseif subcmd == "list" then
          local result = run("git stash list")
          if result == "" then
            vim.notify("No stashes.", vim.log.levels.INFO)
          else
            vim.notify("Stashes:\n" .. result, vim.log.levels.INFO)
          end
        elseif subcmd == "drop" then
          local result = run("git stash drop")
          vim.notify(result ~= "" and result or "Stash dropped.", vim.log.levels.INFO)
        elseif subcmd == "apply" then
          local result = run("git stash apply")
          vim.notify(result ~= "" and result or "Stash applied.", vim.log.levels.INFO)
          vim.cmd("checktime")
        else
          vim.notify("Unknown stash subcommand: " .. subcmd, vim.log.levels.ERROR)
        end
      end, {
        desc = "Git stash operations (push/pop/list/drop/apply)",
        nargs = "?",
        complete = function()
          return { "push", "pop", "list", "drop", "apply" }
        end,
      })

      -- ============================================================
      -- 2. Quick git log for current file
      -- ============================================================
      vim.api.nvim_create_user_command("GitFileLog", function(opts)
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        local count = tonumber(opts.args) or 10
        local file = vim.fn.expand("%:p")
        if file == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end
        local result = run(string.format(
          "git log --oneline --follow -n %d -- %s",
          count,
          vim.fn.shellescape(file)
        ))
        if result == "" then
          vim.notify("No git history for this file.", vim.log.levels.INFO)
        else
          -- Send to quickfix for navigation
          local entries = {}
          for line in result:gmatch("[^\n]+") do
            local hash, msg = line:match("^(%S+)%s+(.*)")
            if hash then
              table.insert(entries, {
                text = hash .. " " .. msg,
                filename = file,
                lnum = 1,
              })
            end
          end
          vim.fn.setqflist(entries, "r")
          vim.fn.setqflist({}, "a", { title = "Git log: " .. vim.fn.fnamemodify(file, ":t") })
          vim.cmd("botright copen")
        end
      end, {
        desc = "Show git log for current file (default: last 10 commits)",
        nargs = "?",
      })

      -- ============================================================
      -- 3. Stage/unstage current file
      -- ============================================================
      vim.api.nvim_create_user_command("GitStageFile", function()
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        local file = vim.fn.expand("%:p")
        if file == "" then return end
        local result = run("git add " .. vim.fn.shellescape(file))
        vim.notify("Staged: " .. vim.fn.fnamemodify(file, ":t") .. (result ~= "" and ("\n" .. result) or ""), vim.log.levels.INFO)
        -- Refresh gitsigns
        pcall(function() require("gitsigns").refresh() end)
      end, { desc = "Stage current file" })

      vim.api.nvim_create_user_command("GitUnstageFile", function()
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        local file = vim.fn.expand("%:p")
        if file == "" then return end
        local result = run("git reset HEAD " .. vim.fn.shellescape(file))
        vim.notify("Unstaged: " .. vim.fn.fnamemodify(file, ":t") .. (result ~= "" and ("\n" .. result) or ""), vim.log.levels.INFO)
        pcall(function() require("gitsigns").refresh() end)
      end, { desc = "Unstage current file" })

      -- ============================================================
      -- 4. Quick commit
      -- ============================================================
      vim.api.nvim_create_user_command("GitCommit", function(opts)
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        local msg = opts.args
        if msg == "" then
          vim.ui.input({ prompt = "Commit message: " }, function(input)
            if not input or input == "" then
              vim.notify("Aborted.", vim.log.levels.INFO)
              return
            end
            local result = run("git commit -m " .. vim.fn.shellescape(input))
            vim.notify(result, vim.log.levels.INFO)
          end)
        else
          local result = run("git commit -m " .. vim.fn.shellescape(msg))
          vim.notify(result, vim.log.levels.INFO)
        end
      end, { desc = "Quick git commit", nargs = "?" })

      -- ============================================================
      -- 5. Conflict markers to quickfix (enhances existing gitsigns quickfix)
      -- ============================================================
      vim.api.nvim_create_user_command("GitConflicts", function()
        if not in_git_repo() then
          vim.notify("Not in a git repository", vim.log.levels.WARN)
          return
        end
        -- Find all conflict markers in the repo
        local result = run("git diff --check HEAD 2>/dev/null || git diff --check 2>/dev/null")
        if result == "" then
          -- Also try grep for markers in tracked files
          result = run("git grep -n '^<<<<<<< ' 2>/dev/null")
        end
        if result == "" then
          vim.notify("No conflicts found.", vim.log.levels.INFO)
          return
        end
        local entries = {}
        for line in result:gmatch("[^\n]+") do
          local file, lnum, text = line:match("^(.+):(%d+):(.*)")
          if file and lnum then
            table.insert(entries, {
              filename = file,
              lnum = tonumber(lnum),
              text = vim.fn.trim(text),
              type = "W",
            })
          end
        end
        if #entries > 0 then
          vim.fn.setqflist(entries, "r")
          vim.fn.setqflist({}, "a", { title = "Git Conflicts" })
          vim.cmd("botright copen")
          vim.notify(string.format("Found %d conflict markers.", #entries), vim.log.levels.WARN)
        else
          vim.notify("No conflict markers found.", vim.log.levels.INFO)
        end
      end, { desc = "Send all git conflict markers to quickfix list" })

      -- ============================================================
      -- 6. Keymaps
      -- ============================================================
      vim.keymap.set("n", "<leader>gS", "<cmd>GitStash<cr>", { desc = "Git stash (push)" })
      vim.keymap.set("n", "<leader>gP", "<cmd>GitStash pop<cr>", { desc = "Git stash pop" })
      vim.keymap.set("n", "<leader>ga", "<cmd>GitStageFile<cr>", { desc = "Stage current file" })
      vim.keymap.set("n", "<leader>gA", "<cmd>GitUnstageFile<cr>", { desc = "Unstage current file" })
      vim.keymap.set("n", "<leader>gc", "<cmd>GitCommit<cr>", { desc = "Quick git commit" })
      vim.keymap.set("n", "<leader>gf", "<cmd>GitFileLog<cr>", { desc = "Git log for current file" })
      vim.keymap.set("n", "<leader>gx", "<cmd>GitConflicts<cr>", { desc = "Conflict markers to quickfix" })
    end,
  },
}
