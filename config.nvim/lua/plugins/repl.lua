-- REPL integration for Neovim.
-- Addresses nvim-config#10: Learn about REPL.
--
-- Features:
--   1. Auto-completion configuration for DAP REPL buffers
--   2. C-c clears the current line in REPL/terminal buffers
--   3. Send visual selection or current line to a REPL
--   4. Language-aware REPL spawning

return {
  {
    -- Virtual plugin for REPL integration
    dir = vim.fn.stdpath("config"),
    name = "nvim-repl",
    lazy = false,
    config = function()
      -- ============================================================
      -- 1. DAP REPL auto-completion
      -- ============================================================
      -- nvim-dap provides omnifunc for the REPL buffer.
      -- Set up auto-triggering of completion in dap-repl buffers.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "dap-repl" },
        callback = function(args)
          -- Enable omnifunc-based completion (nvim-dap sets omnifunc automatically)
          -- Trigger completion on typing
          vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = args.buf,
            callback = function()
              -- Only trigger if we're actually typing (not from completion itself)
              if vim.fn.pumvisible() == 1 then
                return
              end
              -- Get current line content before cursor
              local line = vim.api.nvim_get_current_line()
              local col = vim.fn.col(".")
              local before_cursor = line:sub(1, col - 1)

              -- Trigger completion if we have at least 1 char of a word
              if before_cursor:match("[%w_%.:]$") then
                -- Small delay to avoid too-frequent triggering
                vim.defer_fn(function()
                  if vim.fn.pumvisible() == 0 and vim.fn.mode() == "i" then
                    vim.api.nvim_feedkeys(
                      vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true),
                      "n", false
                    )
                  end
                end, 150)
              end
            end,
          })

          -- Better completion accept behavior
          vim.keymap.set("i", "<Tab>", function()
            if vim.fn.pumvisible() == 1 then
              return vim.api.nvim_replace_termcodes("<C-n>", true, false, true)
            else
              return vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
            end
          end, { buffer = args.buf, expr = true, desc = "Tab to navigate completion in REPL" })

          vim.keymap.set("i", "<S-Tab>", function()
            if vim.fn.pumvisible() == 1 then
              return vim.api.nvim_replace_termcodes("<C-p>", true, false, true)
            else
              return vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true)
            end
          end, { buffer = args.buf, expr = true, desc = "S-Tab to navigate completion in REPL" })

          vim.keymap.set("i", "<CR>", function()
            if vim.fn.pumvisible() == 1 then
              return vim.api.nvim_replace_termcodes("<C-y>", true, false, true)
            else
              return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
            end
          end, { buffer = args.buf, expr = true, desc = "CR to accept completion in REPL" })
        end,
      })

      -- ============================================================
      -- 2. C-c clears current input line in dap-repl buffers
      -- ============================================================
      -- NOTE: A TermOpen autocmd that mapped <C-c> in terminal mode was removed
      -- here (fix for issue #50). It used nvim_feedkeys with "t" flag, which
      -- caused infinite recursion: the fed keys went through mapping resolution,
      -- re-triggering the same mapping, freezing Neovim. The mapping was also
      -- redundant — Neovim already sends SIGINT on <C-c> in terminal buffers.

      -- For dap-repl specifically, C-c should clear the current input
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "dap-repl" },
        callback = function(args)
          -- In insert mode in dap-repl, C-c clears the current line
          vim.keymap.set("i", "<C-c>", function()
            -- Clear the current input line
            local line_count = vim.api.nvim_buf_line_count(0)
            local current_line = vim.fn.line(".")
            -- Only clear if we're on the last (input) line
            if current_line == line_count then
              vim.api.nvim_set_current_line("")
              -- Move cursor to end
              vim.cmd("startinsert!")
            else
              -- If not on input line, just escape
              vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
                "n", false
              )
            end
          end, { buffer = args.buf, desc = "Clear current REPL input line" })
        end,
      })

      -- ============================================================
      -- 3. Send to REPL functionality
      -- ============================================================
      -- Track the current REPL terminal job id
      vim.g._repl_job_id = nil
      vim.g._repl_buf_id = nil

      ---@type table<string, table>
      local repl_commands = {
        python = { cmd = "python3", alt = "ipython" },
        lua = { cmd = "lua", alt = "luajit" },
        javascript = { cmd = "node" },
        typescript = { cmd = "npx ts-node" },
        ruby = { cmd = "irb" },
        sh = { cmd = "bash" },
        zsh = { cmd = "zsh" },
        r = { cmd = "R" },
        julia = { cmd = "julia" },
        haskell = { cmd = "ghci" },
        ocaml = { cmd = "utop", alt = "ocaml" },
        rust = { cmd = "evcxr" },
        go = { cmd = "gore", alt = "" },
      }

      --- Open a REPL for the current filetype
      local function open_repl(filetype)
        filetype = filetype or vim.bo.filetype

        local repl_config = repl_commands[filetype]
        if not repl_config then
          vim.notify("No REPL configured for filetype: " .. filetype, vim.log.levels.WARN)
          return
        end

        -- Determine which command to use
        local cmd = repl_config.cmd
        if vim.fn.executable(vim.split(cmd, " ")[1]) == 0 then
          if repl_config.alt and vim.fn.executable(vim.split(repl_config.alt, " ")[1]) == 1 then
            cmd = repl_config.alt
          else
            vim.notify("REPL command not found: " .. cmd, vim.log.levels.ERROR)
            return
          end
        end

        -- Open terminal in a vertical split
        vim.cmd("botright vsplit")
        vim.cmd("terminal " .. cmd)

        vim.g._repl_job_id = vim.b.terminal_job_id
        vim.g._repl_buf_id = vim.api.nvim_get_current_buf()

        -- Set buffer-local options
        vim.bo.buflisted = false

        -- Return to the previous window
        vim.cmd("wincmd p")
        vim.print_silent("REPL started: " .. cmd)
      end

      --- Send text to the active REPL
      ---@param text string
      local function send_to_repl(text)
        if not vim.g._repl_job_id then
          vim.notify("No active REPL. Use :ReplOpen to start one.", vim.log.levels.WARN)
          return
        end

        -- Check if the REPL buffer is still valid
        if not vim.g._repl_buf_id or not vim.api.nvim_buf_is_valid(vim.g._repl_buf_id) then
          vim.g._repl_job_id = nil
          vim.g._repl_buf_id = nil
          vim.notify("REPL buffer closed. Use :ReplOpen to start a new one.", vim.log.levels.WARN)
          return
        end

        -- Send each line individually for proper REPL handling
        local lines = vim.split(text, "\n")
        for _, line in ipairs(lines) do
          vim.fn.chansend(vim.g._repl_job_id, line .. "\n")
        end
      end

      -- ============================================================
      -- Commands
      -- ============================================================
      vim.api.nvim_create_user_command("ReplOpen", function(opts)
        local ft = opts.args and #opts.args > 0 and opts.args or nil
        open_repl(ft)
      end, {
        desc = "Open a REPL for the current (or specified) filetype",
        nargs = "?",
        complete = function()
          local fts = {}
          for ft, _ in pairs(repl_commands) do
            table.insert(fts, ft)
          end
          table.sort(fts)
          return fts
        end,
      })

      vim.api.nvim_create_user_command("ReplSend", function(opts)
        if opts.range > 0 then
          -- Range command: send selected lines
          local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
          send_to_repl(table.concat(lines, "\n"))
        else
          -- No range: send current line
          send_to_repl(vim.api.nvim_get_current_line())
        end
      end, {
        desc = "Send current line or selection to REPL",
        range = true,
      })

      vim.api.nvim_create_user_command("ReplClose", function()
        if vim.g._repl_buf_id and vim.api.nvim_buf_is_valid(vim.g._repl_buf_id) then
          vim.api.nvim_buf_delete(vim.g._repl_buf_id, { force = true })
        end
        vim.g._repl_job_id = nil
        vim.g._repl_buf_id = nil
        vim.print_silent("REPL closed.")
      end, { desc = "Close the active REPL" })

      -- ============================================================
      -- Keymaps
      -- ============================================================
      vim.keymap.set("n", "<leader>ro", "<cmd>ReplOpen<cr>", { desc = "Open REPL for current filetype" })
      vim.keymap.set("n", "<leader>rq", "<cmd>ReplClose<cr>", { desc = "Close active REPL" })
      vim.keymap.set("n", "<leader>rs", "<cmd>ReplSend<cr>", { desc = "Send current line to REPL" })
      vim.keymap.set("v", "<leader>rs", ":'<,'>ReplSend<cr>", { desc = "Send selection to REPL" })
      vim.keymap.set("n", "<leader>rr", function()
        -- Send entire buffer to REPL
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        send_to_repl(table.concat(lines, "\n"))
      end, { desc = "Send entire buffer to REPL" })
    end,
  },
}
