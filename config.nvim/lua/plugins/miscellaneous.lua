-- since this is just an example spec, don't actually load anything here and return an empty spec
-- stylua: ignore
-- if true then return {} end

-- ************************ Snacks helper functions ************************ --
---@class snacks.Picker
---@field [string] unknown
---@class snacks.picker.Config
---@field [string] unknown

local list_extend = function(where, what)
  return vim.list_extend(vim.deepcopy(where), what)
end

local list_filter = function(where, what)
  -- stylua: ignore
  return vim.iter(where):filter(function(val) return not vim.list_contains(what, val) end):totable()
end

local is_git_item = function(item, git_nodes)
  return vim.iter(git_nodes):any(function(node)
    if node.dir_status then
      return vim.fs.relpath(node.path, item.file) ~= nil
    end
    return vim.fs.relpath(item.file, node.path) ~= nil
  end)
end

-- ************************  Snacks helper actions  ************************ --
---@param picker snacks.Picker
---@param item snacks.picker.Item
local search_from_selected = function(picker, item)
  -- If any files selected, search from the files.
  local multi_selection = picker:selected { fallback = false }

  -- If non selected, and there is a directory under the cursor, search in the directory.
  if not multi_selection or #multi_selection == 0 then
    multi_selection = {}
    if not item.dir then
      vim.print_silent("not directory. Could not search here.")
      return
    end
    multi_selection = { item.file or item._path }
  else
    local files = {}
    for _, item in ipairs(multi_selection) do
      table.insert(files, item.file)
    end
    multi_selection = files
  end
  vim.schedule(function()
    picker:close()
    Snacks.picker.grep({
      dirs = multi_selection,
      certain_files = true,
      toggles = {
        certain_files = "f" .. #(multi_selection)
      }
    })
  end)
end

return {
  -- Disable some of the builtin plugins.
  -- {
  --   "LazyVim/LazyVim",
  --   version = "12.44.1",
  --   opts = {
  --     colorscheme = "dracula",
  --   },
  -- },
  {
    'kevinhwang91/nvim-ufo',
    dependencies = { 'kevinhwang91/promise-async' },
    config = function()
      vim.o.foldenable = true
      vim.o.foldcolumn = '0' -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
      vim.keymap.set('n', 'zr', require('ufo').openFoldsExceptKinds)
      vim.keymap.set('n', 'zm', require('ufo').closeFoldsWith)
      require('ufo').setup({
        open_fold_hl_timeout = 150,
        provider_selector = function(bufnr, filetype, buftype)
          return {'treesitter', 'indent'}
        end}
      )
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "HiPhish/rainbow-delimiters.nvim" },
    opts = function(_, opts)
      opts.auto_install = true
      opts.rainbow = {
        enable = true,
        query = "rainbow-delimiters",
        strategy = require("rainbow-delimiters").strategy.global,
      }
      opts.ensure_installed = {
        "bash",
        "python", -- Pylance does not support highlighting.

        -- Cpp related.
        "cpp", -- clangd provides very barren highlighting. `See https://github.com/clangd/clangd/issues/1115`
        "make",
        "cmake",

        -- "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",

        -- Programming languages.
        "rust",
        "go",
        "gomod",
        "gosum",

        -- Vim.
        "vim",
        "vimdoc",

        -- Markup Languages.
        "yaml",
        "toml",
        "json",
        "xml",
        -- "json5",

        -- Others.
        "diff",
        "ssh_config",
        "gitignore"
      }

      -- zsh does not own its parser. So use bash.
      vim.treesitter.language.register("bash", "zsh")

      -- Tried to use opts.highlight.enable, but it did not work.
      -- if vim.g.use_treesitter_highlight then
      --   vim.cmd[[ TSEnable highlight ]]
      -- else 
      --   vim.cmd[[ TSDisable highlight ]]
      -- end
      opts.indent = {
        disable = true,
      }
      return opts
    end,
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    dependencies = {
      "folke/todo-comments.nvim",
    },
    keys = {
      { "<leader>bb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>bb", function() Snacks.picker.buffers({ search = vim.g.function_get_selected_content() }) end, desc = "Buffers", mode = {"v"} }, -- maybe not to be used.. but let's just leave it here.
      { "<leader>bB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      { "<leader>bB", function() Snacks.picker.grep_buffers({ search = vim.g.function_get_selected_content() }) end, desc = "Grep Open Buffers", mode = {"v"} },

      -- Search
      -- { "<leader>/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>/", function() Snacks.picker.grep({ search = vim.g.function_get_selected_content() }) end, desc = "Grep", mode = "v" },
      { "<c-/>", function() Snacks.picker.lines() end, desc = "Line inspect" },
      { "<c-/>", function() Snacks.picker.lines({ pattern = vim.g.function_get_selected_content() }) end, desc = "Line inspect", mode = "v"},

      -- File browsing.
      { "<leader>fe", function() Snacks.explorer() end, desc = "File Explorer" },
      { "<leader>fE", function() Snacks.picker.explorer({cwd = vim.fn.expand("%:p:h")}) end, desc = "File Explorer of the current opened file" },
      { "<leader>fe", function() Snacks.explorer({ pattern = vim.g.function_get_selected_content() }) end, desc = "File Explorer", mode = "v" },
      { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      { "<leader>ff", function() Snacks.picker.smart({ pattern = vim.g.function_get_selected_content() }) end, desc = "Smart Find Files", mode = "v" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>fo", function() vim.cmd[[SnackOldfiles]] end, desc = "Recent" },

      -- Symbol browsing
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols({ pattern = vim.g.function_get_selected_content() }) end, desc = "LSP Symbols", mode = "v" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols({ pattern = vim.g.function_get_selected_content()}) end, desc = "LSP Workspace Symbols", mode = "v" },

      -- Git diffing
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },

      -- Help browsing
      { "<leader>fh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>fh", function() Snacks.picker.help({ pattern = vim.g.function_get_selected_content()}) end, desc = "Help Pages", mode = "v" },

      -- Todo browsing. 
      { "<leader>lt", function() Snacks.picker.todo_comments() end, desc = "List Todo Comments" },

      -- Keymap browsing.
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },

      -- Diagnostics browsing.
      { "<leader>jJ", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>jj", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },

      -- Jump list browsing.
      { "<leader>jk", function() Snacks.picker.jumps() end, desc = "Jump list" },

      -- LSP related browsing.
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
      { "gy", function() Snacks.picker.lsp_type_definitions({ pattern = vim.g.function_get_selected_content()}) end, desc = "Goto T[y]pe Definition", mode = "v" },
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
      { "gd", function() Snacks.picker.lsp_definitions({ pattern = vim.g.function_get_selected_content()}) end, desc = "Goto Definition", mode = "v" },
      { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
      { "gr", function() Snacks.picker.lsp_references({ pattern = vim.g.function_get_selected_content()}) end, nowait = true, desc = "References", mode = "v" },
      { "gi", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
      { "gi", function() Snacks.picker.lsp_implementations({ pattern = vim.g.function_get_selected_content()}) end, desc = "Goto Implementation", mode = "v" },

      -- Redo
      { "<leader>tT", function() Snacks.picker.resume() end, desc = "Resume" },

      -- { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
      -- Command.
      { "<leader>pp", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>pp", function() Snacks.picker.command_history({ pattern = vim.g.function_get_selected_content()}) end, desc = "Command History", mode = "v" },
      { "<leader>pP", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>pP", function() Snacks.picker.commands({ pattern = vim.g.function_get_selected_content()}) end, desc = "Commands", mode = "v" },

      -- Navigation
      { "<leader>zz", function() Snacks.picker.zoxide() end, desc = "Zoxide cwd navigation" },
      { "<leader>zz", function() Snacks.picker.zoxide({ pattern = vim.g.function_get_selected_content()}) end, desc = "Zoxide cwd navigation", mode = "v"},
    },
    opts = {
      bigfile = { enabled = true },
      dashboard = { enabled = false },
      explorer = {
        enabled = true
      },
      gh = {
        enabled = true,
      },
      styles = {
        lazygit = {
          height = 0,
          width = 0,
        },
        input = {
          relative = "cursor",
          row = 1,
          col = 3,
          width = 30,
        },
        terminal = {
          keys = {
            ["<D-t>"] = {
              function(self)
                 self:hide()
              end,
              mode = "t",
              expr = true,
            },
            gf = function(self)
              local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
              if f == "" then
                Snacks.notify.warn("No file under cursor")
              else
                self:hide()
                vim.schedule(function()
                  vim.cmd("e " .. f)
                end)
              end
            end,
            term_normal = {
              "<esc>",
              function(self)
                self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
                if self.esc_timer:is_active() then
                  self.esc_timer:stop()
                  vim.cmd("stopinsert")
                else
                  self.esc_timer:start(200, 0, function() end)
                  return "<esc>"
                end
              end,
              mode = "t",
              expr = true,
              desc = "Double escape to normal mode",
            },
          }
        }
      },
      -- indent = { enabled = false },
      input = {
        enabled = true,
      },
      indent = { enabled = false },
      notify = { enabled = false },
      notifier = { enabled = false },
      quickfile = { enabled = false },
      scope = { enabled = false },
      -- BUGREPORT: existing issue jitting neovide scrolling when opening buf in multiple window: https://github.com/neovide/neovide/issues/3094
      -- caused by nvim upstream. Enabling smooth scroll would workaround this use, but cause slow cursor move.
      scroll = { enabled = false },
      -- statuscolumn = { enabled = false },
      words = { enabled = false },
      picker = {
        layout = { preset = "dropdown" },
        win = {
          input = {
            keys = {
              -- navigation.
              ["<c-x>"] = {"edit_split", mode = {"n", "i"}},
              -- ["<c-s>"] = {"edit_split", mode = {"n", "i"}},
              -- ["<c-v>"] = {"edit_vsplit", mode = { "n", "i" }},
              ["<c-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              ["<d-x>"] = {"edit_split", mode = {"n", "i"}},
              ["<d-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              -- ["<d-s>"] = {"edit_split", mode = {"n", "i"}},

              -- Toggling hidden
              ["<c-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["<d-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["H"] = { "toggle_hidden", mode = { "n" } },

              -- Windows switching.
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-S-Tab>"] = {"reverse_cycle_win", mode = {"n", "i"}},
              ["<C-k>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-j>"] = {"reverse_cycle_win", mode = {"n", "i"}},

              -- History moving
              ["<d-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-k>"] = { "history_back", mode = { "n", "i" } },
              ["<d-s-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-s-k>"] = { "history_back", mode = { "n", "i" } },

              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
              ["<d-t>"] = {"new_tab_here", mode={"n", "i"}}, -- no terminal response when floating window is opened.

              -- Searching from all the current files or selected files.
              ["<C-/>"] = {"search_from_selected", mode={"n", "i"}},
              ["<D-/>"] = {"search_from_selected", mode={"n", "i"}},

              -- Directory view from the item path.
              ["<c-e>"] = { "explore_here", mode = { "n", "i" } },
              ["<d-e>"] = { "explore_here", mode = { "n", "i" } },

              -- Maximize.
              ["<D-o>"] = {"maximize", mode = { "n", "i" }},
              ["<C-o>"] = {"maximize", mode = { "n", "i" }},
              ["o"] = "maximize", -- Input shall not have new line.

              -- Inspecting.
              ["<c-p>"] = "inspect",
              ["<d-p>"] = "inspect",
              ["<c-P>"] = { "picker_print", mode = { "n", "i" } },
              ["<d-P>"] = { "picker_print", mode = { "n", "i" } },
            }
          },
          list = {
            keys = {
              -- Window switching.
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-S-Tab>"] = {"reverse_cycle_win", mode = {"n", "i"}},
              ["<C-k>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-j>"] = {"reverse_cycle_win", mode = {"n", "i"}},

              -- History moving
              ["<d-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-k>"] = { "history_back", mode = { "n", "i" } },
              ["<d-s-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-s-k>"] = { "history_back", mode = { "n", "i" } },

              -- Toggle hidden.
              ["<c-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["<d-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["H"] = { "toggle_hidden", mode = { "n" } },

              -- Tab open.
              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
              ["<d-t>"] = {"new_tab_here", mode={"n", "i"}},
              ["t"] = {"new_tab_here", mode={"n", "i"}},

              ["<C-/>"] = {"search_from_selected", mode={"n", "i"}},
              ["<D-/>"] = {"search_from_selected", mode={"n", "i"}},

              -- Window switching
              ["<c-x>"] = {"edit_split", mode = {"n", "i"}},
              -- ["<c-s>"] = {"edit_split", mode = {"n", "i"}},
              -- ["<c-v>"] = {"edit_vsplit", mode = { "n", "i" }},
              ["<c-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              ["<d-x>"] = {"edit_split", mode = {"n", "i"}},
              ["<d-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              -- ["<d-s>"] = {"edit_split", mode = {"n", "i"}},
              ["x"] = "edit_split",
              ["X"] = "edit_vsplit",
              ["v"] = "edit_vsplit",

              -- Maximize.
              ["<D-o>"] = {"maximize", mode = { "n", "i" }},
              ["<C-o>"] = {"maximize", mode = { "n", "i" }},
              ["o"] = "maximize",

              -- Directory view from the item path.
              ["<c-e>"] = { "explore_here", mode = { "n", "i" } },
              ["<d-e>"] = { "explore_here", mode = { "n", "i" } },
              ["<e>"] = { "explore_here", mode = { "n" } },

              -- Inspecting.
              ["<c-p>"] = "inspect",
              ["<d-p>"] = "inspect",
              ["p"] = "inspect",

              ["A"] = "toggle_focus",
              ["a"] = "toggle_focus",
              ["i"] = "toggle_focus",
              ["I"] = "toggle_focus",
            }
          },
          preview = {
            keys = {
              -- Window shifting.
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-S-Tab>"] = {"reverse_cycle_win", mode = {"n", "i"}},
              ["<C-k>"] = {"cycle_win", mode = {"n", "i"}},
              ["<C-j>"] = {"reverse_cycle_win", mode = {"n", "i"}},

              -- History moving
              ["<d-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-k>"] = { "history_back", mode = { "n", "i" } },
              ["<d-s-j>"] = { "history_forward", mode = { "n", "i" } },
              ["<d-s-k>"] = { "history_back", mode = { "n", "i" } },

              -- Tab Opening.
              ["t"] = {"new_tab_here", mode={"n", "i"}},
              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
              ["<d-t>"] = {"new_tab_here", mode={"n", "i"}},

              ["<c-x>"] = {"edit_split", mode = {"n", "i"}},
              ["<c-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              -- ["<c-s>"] = {"edit_split", mode = {"n", "i"}},
              -- ["<c-v>"] = {"edit_vsplit", mode = { "n", "i" }},
              ["<d-x>"] = {"edit_split", mode = {"n", "i"}},
              ["<d-s-x>"] = {"edit_vsplit", mode = {"n", "i"}},
              -- ["<d-s>"] = {"edit_split", mode = {"n", "i"}},
              ["x"] = "edit_split",
              ["X"] = "edit_vsplit",
              ["v"] = "edit_vsplit",

              -- Maximize.
              ["<D-o>"] = {"maximize", mode = { "n", "i" }},
              ["<C-o>"] = {"maximize", mode = { "n", "i" }},
              ["o"] = "maximize",

              -- Print.
              ["<c-p>"] = "inspect",
              ["<d-p>"] = "inspect",
              ["p"] = "inspect",

              -- Focus.
              ["A"] = "toggle_focus",
              ["a"] = "toggle_focus",
              ["i"] = "toggle_focus",
              ["I"] = "toggle_focus",
            }
          }
        },
        actions = {
          ---@param picker snacks.Picker
          ---@param item? snacks.picker.Item
          maximize = function(picker, _)
            local layout_config = vim.deepcopy(picker.resolved_layout)
            if layout_config.preview == 'main' or not picker.preview.win:valid() then
              return
            end

            -- Toggle maximizing the whole floating window.
            layout_config.fullscreen = not layout_config.fullscreen

            -- 1. find preview window and get height
            local function find_preview(root) ---@param root snacks.layout.Box|snacks.layout.Win
              if root.win == 'preview' then
                return root
              end
              if #root then
                for _, w in ipairs(root) do
                  local preview = find_preview(w)
                  if preview then
                    return preview
                  end
                end
              end
              return nil
            end
            local preview = find_preview(layout_config.layout)
            if not preview then
              return
            end
            local eval = function(s)
              return type(s) == 'function' and s(preview.win) or s
            end
            --- @type number?
            local height = eval(preview.height)
            if not height then
              return
            end

            -- 2. calculate height
            if picker.orig_height then ---@diagnostic disable-line: inject-field
              -- reset to original height
              height = picker.orig_height
              picker.orig_height = nil ---@diagnostic disable-line: inject-field
            else
              -- set to larger height
              picker.orig_height = height ---@diagnostic disable-line: inject-field
              height = 0.8
            end

            -- 3. set the height
            preview['height'] = height
            picker:set_layout(layout_config)
          end,
          explore_here = function (_, item)
            if item.dir and item.file then
              local path  = (
                function()
                  local candidates = { item._path or "", item.file or "" }
                  for _, c in ipairs(candidates) do
                    if #c > 0 then
                      return c
                    end
                  end
                  return ""
                end
              )()
              if #path == 0 then
                return
              end
              Snacks.picker.explorer({ cwd = path })
            else
              vim.print_silent("no directory related")
            end
          end,
          picker_print = function(picker, _)
            vim.print(picker)
          end,
          to_preview = function(picker, _)
            if vim.api.nvim_win_is_valid(picker.preview.win.win) then
              vim.api.nvim_set_current_win(picker.preview.win.win)
            else
              vim.notify("Target window is not valid.", vim.log.levels.WARN)
            end
          end,
          to_input = function(picker, _)
            if vim.api.nvim_win_is_valid(picker.input.win.win) then
              vim.api.nvim_set_current_win(picker.input.win.win)
            else
              vim.notify("Target window is not valid.", vim.log.levels.WARN)
            end
            vim.api.nvim_set_current_win(picker.input.win.win)
          end,
          new_tab_here = function(_, item)
            vim.cmd[[ tabnew ]]
            if item.dir then
              Snacks.picker.actions.tcd(_, item)
              vim.cmd('silent !zoxide add "' .. item._path .. '"')
              vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
            else
              vim.cmd("e " .. item._path)
            end
          end,
          -- cycle with some order. TODO: Not tested. Rethink if we do really need it.
          reverse_cycle_win = function (picker)
            local wins = { picker.input.win.win, picker.list.win.win, picker.preview.win.win }
            wins = vim.tbl_filter(function(w)
              return vim.api.nvim_win_is_valid(w)
            end, wins)
            local last_win = vim.api.nvim_get_current_win()
            local idx = 1
            for i, w in ipairs(wins) do
              if w == last_win then
                idx = i
                break
              end
            end
            local win = wins[idx % #wins + 1] or 1 -- cycle
            vim.api.nvim_set_current_win(win)
            -- When switching from other windows to the current, select the line.
            if last_win ~= picker.input.win.win and win == picker.input.win.win then
              -- It did not work. Fix it later.
              -- vim.print("debug: to input.")
              picker.list:set_selected()
              picker.list:set_target()
              picker:find()
            end
          end,
          v_new_win_here = function (picker, item)
            picker:close()
            vim.cmd[[ Vsplit ]]
            Snacks.picker.actions.lcd(_, item)
            vim.print_silent("Win pwd: " .. vim.fn.getcwd())
          end,
          x_new_win_here = function (picker, item)
            picker:close()
            vim.cmd[[ Split ]]
            Snacks.picker.actions.lcd(_, item)
            vim.print_silent("Win pwd: " .. vim.fn.getcwd())
          end,
          search_from_selected = search_from_selected,
        },
        -- As neovim has no window-local keymap.
        -- Display view that uses opened buffer will not oevrride keymaps. 
        -- Confirmed by author.
        sources = {
          git_grep = {
            supports_live = false,
            format = function(item, picker)
              local file_format = Snacks.picker.format.file(item, picker)
              vim.api.nvim_set_hl(0, 'SnacksPickerGitGrepLineNew', { link = 'Added' })
              vim.api.nvim_set_hl(0, 'SnacksPickerGitGrepLineOld', { link = 'Removed' })
              if item.sign == '+' then
                file_format[#file_format - 1][2] = 'SnacksPickerGitGrepLineNew'
              else
                file_format[#file_format - 1][2] = 'SnacksPickerGitGrepLineOld'
              end
              return file_format
            end,
            finder = function(_, ctx)
              local hcount = 0
              local header = {
                file = '',
                old = { start = 0, count = 0 },
                new = { start = 0, count = 0 },
              }
              local sign_count = 0
              return require('snacks.picker.source.proc').proc(
                ctx:opts {
                  cmd = 'git',
                  args = { 'diff', '--unified=0' },
                  transform = function(item) ---@param item snacks.picker.finder.Item
                    local line = item.text
                    -- [[Header]]
                    if line:match '^diff' then
                      hcount = 3
                    elseif hcount > 0 then
                      if hcount == 1 then
                        header.file = line:sub(7)
                      end
                      hcount = hcount - 1
                    elseif line:match '^@@' then
                      local parts = vim.split(line:match '@@ ([^@]+) @@', ' ')
                      local old_start, old_count = parts[1]:match '-(%d+),?(%d*)'
                      local new_start, new_count = parts[2]:match '+(%d+),?(%d*)'
                      header.old.start, header.old.count = tonumber(old_start), tonumber(old_count) or 1
                      header.new.start, header.new.count = tonumber(new_start), tonumber(new_count) or 1
                      sign_count = 0
                      -- [[Body]]
                    elseif not line:match '^[+-]' then
                      sign_count = 0
                    elseif line:match '^[+-]%s*$' then
                      sign_count = sign_count + 1
                    else
                      item.sign = line:sub(1, 1)
                      item.file = header.file
                      item.line = line:sub(2)
                      if item.sign == '+' then
                        item.pos = { header.new.start + sign_count, 0 }
                        sign_count = sign_count + 1
                      else
                        item.pos = { header.new.start, 0 }
                        sign_count = 0
                      end
                      return true
                    end
                    return false
                  end,
                },
                ctx
              )
            end,
          },
          gh_issue = {},
          gh_pr = {},
          grep = {
            case_sens = false, -- New! Define custom variable
            toggles = {
              case_sens = 's',
            },
            finder = function(opts, ctx)
              local args_extend = { '--case-sensitive' }
              opts.args = list_filter(opts.args or {}, args_extend)
              if opts.case_sens then
                opts.args = list_extend(opts.args, args_extend)
              end
              -- vim.print(opts.args) -- Debug
              return require('snacks.picker.source.grep').grep(opts, ctx)
            end,
            actions = {
              toggle_live_case_sens = function(picker) -- [[Override]]
                picker.opts.case_sens = not picker.opts.case_sens
                picker:find()
              end,
              ---@param picker snacks.Picker
              ---@param item? snacks.picker.Item
              remove_file_from_list = function (picker, item)
                -- get filename of the item.
                if not item or not item.file then
                  return
                end
                -- exclude it from searching
                -- FIXME: how to get the original picker opts.
                table.insert(picker.main, "--iglob=!" .. item.file)
                -- respawn search.
                picker.list:set_target()
                picker:find()
              end
            },
            win = {
              input = {
                keys = {
                  ["<c-i>"] = {"remove_file_from_list", mode = {"n", "i"}},
                  ["<d-i>"] = {"remove_file_from_list", mode = {"n", "i"}},
                  ['<c-s>'] = { 'toggle_live_case_sens', mode = { 'i', 'n' } },
                  ['<d-s>'] = { 'toggle_live_case_sens', mode = { 'i', 'n' } },

                  ["<c-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                  ["<d-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                }
              },
              list = {
                keys = {
                  ["<c-i>"] = {"remove_file_from_list", mode = {"n", "i"}},
                  ["<d-i>"] = {"remove_file_from_list", mode = {"n", "i"}},
                  ['<c-s>'] = { 'toggle_live_case_sens', mode = { 'i', 'n' } },
                  ['<d-s>'] = { 'toggle_live_case_sens', mode = { 'i', 'n' } },

                  ["<c-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                  ["<d-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                }
              }
            }
          },
          yanky = {
            actions = {
              -- Paste from `yanky/lua/yanky/sources/snacks.lua`. It's not respecting visual mode.
              confirm = function(picker)
                picker:close()
                local selected = picker:selected({ fallback = true })

                if vim.tbl_count(selected) == 1 then
                  require("yanky.picker").actions.put("p", vim.g.__local_is_visual_mode_before_yanky_picker or false)(selected[1])
                  return
                end
                local content = {
                  regcontents = "",
                  regtype = "V",
                }
                for _, current in ipairs(selected) do
                  content.regcontents = content.regcontents .. current.regcontents
                  if current.regtype == "v" then
                    content.regcontents = content.regcontents .. "\n"
                  end
                end
                require("yanky.picker").actions.put("p", vim.g.__local_is_visual_mode_before_yanky_picker or false)(content)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<c-s-x>"] = false,
                  ["<c-x>"] = false,
                }
              }
            }
          },
          -- Now migrate to customized recent picker. Deprecated for now.
          recent = {
            -- filter = {
            --   paths = {
            --     [vim.fn.stdpath("data")] = true
            --   },
            -- },
            -- actions = {
            --   toggle_global = function(picker, item)
            --     if picker and picker.title == "Recent (Cwd)" then
            --       Snacks.picker.recent({ title = "Recent (Global)", hidden = true, filter = { cwd = false,
            --       paths = {
            --         [vim.fn.stdpath("data")] = true,
            --         [vim.fn.stdpath("cache")] = true,
            --         [vim.fn.stdpath("state")] = true,
            --       }
            --       } })
            --     else
            --       Snacks.picker.recent({ title = "Recent (Cwd)", hidden = false, filter = { cwd = true,
            --         paths = {
            --           [vim.fn.stdpath("data")] = true,
            --           [vim.fn.stdpath("cache")] = true,
            --           [vim.fn.stdpath("state")] = true,
            --         }
            --     } })
            --     end
            --   end
            -- },
            -- win = {
            --   input = {
            --     keys = {
            --       ["<c-g>"] = {"toggle_global", mode={"n", "i"}}
            --     }
            --   }
            -- }
          },
          keymaps = {
            actions = {
              go_to_if_possible = function (_, item)
                if item._path and #item._path ~= 0 then
                    vim.cmd[[ tabnew ]]
                    Snacks.picker.actions.tcd(_, item)
                    vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
                    vim.cmd("e " .. item._path)
                  else
                    vim.notify("No path for keymap.")
                  end
                end
            },
            win = {
              input = {
                keys = {
                  ["<c-t>"] = { "go_to_if_possible" , mode={"n", "i"}},
                }
              }
            }
          },
          diagnostics = {
            win = {
              preview = {
                keys = {
                  ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
                  ["<C-k>"] = {"cycle_win", mode = {"n", "i"}},
                  ["<C-S-Tab>"] = {"reverse_cycle_win", mode = {"n", "i"}},
                  ["<C-j>"] = {"reverse_cycle_win", mode = {"n", "i"}},
                }
              }
            }
          },
          diagnostics_buffer = {
            win = {
              preview = {
                keys = {
                  ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
                  ["<C-k>"] = {"cycle_win", mode = {"n", "i"}},
                  ["<C-S-Tab>"] = {"reverse_cycle_win", mode = {"n", "i"}},
                  ["<C-j>"] = {"reverse_cycle_win", mode = {"n", "i"}},
                }
              }
            }
          },
          explorer = {
            -- your explorer picker configuration comes here
            -- or leave it empty to use the default settings
            layout = { preset = "dropdown", preview = true, cycle = true },
            diagnostics_open = true,
            focus = "input",
            auto_close = true,
            only_git = false,
            toggles = {
              only_git = "S",
            },
            finder = function(opts, ctx)
              local Tree = require("snacks.explorer.tree")
              local git_nodes = {}
              Tree:walk(Tree:find(ctx.picker:cwd()), function(node)
                if node.status then
                  table.insert(git_nodes, node)
                end
              end)
              ctx.picker.git_nodes = git_nodes
              return require("snacks.picker.source.explorer").explorer(opts, ctx)
            end,
            -- Config
            transform = function(item, ctx)
              if ctx.picker.opts.only_git then
                return is_git_item(item, ctx.picker.git_nodes)
              end
            end,
            actions = {
              -- TODO: if it's a file, open without unfold it.
              tcd_to_item = function (picker, item)
                picker:close()
                vim.cmd('silent !zoxide add "' .. item._path .. '"')
                vim.cmd.tcd(item._path)
                vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
              end,
              add_to_zoxide = function(_, item)
                vim.cmd('silent !zoxide add "' .. item._path .. '"')
                vim.notify("Path " .. item._path .. " added to zoxide path.", vim.log.levels.INFO)
              end,
              explorer_up = function(picker) --[[Override]]
                picker.up_stack = picker.up_stack or {}
                local cwd = picker:cwd()
                local parent = vim.fs.dirname(cwd)
                if cwd == parent then -- root
                  return
                end
                table.insert(picker.up_stack, cwd)
                -- TIP: Same as `picker:set_cwd` & `picker:find`
                vim.api.nvim_set_current_dir(parent)
              end,
              explorer_down = function(picker, item)
                if not item.parent and not vim.tbl_isempty(picker.up_stack or {}) then
                  vim.api.nvim_set_current_dir(table.remove(picker.up_stack))
                else
                  picker.up_stack = {}
                  vim.api.nvim_set_current_dir(picker:dir())
                end
              end,
            },
            win = {
              input = {
                keys = {
                  ["<d-bs>"]= { "explorer_up", mode = { "n", "i" } },
                  ["<d-s-bs>"]= { "explorer_down", mode = { "n", "i" } },

                  -- Toggle git only
                  ["S"] = { "toggle_only_git", mode = { "n" } },
                  ["<C-S>"] = { "toggle_only_git", mode = { "n", "i" } },
                  ["<D-S>"] = { "toggle_only_git", mode = { "n", "i" } },

                  ["<c-p>"] = {"inspect", mode = { "n", "i" }},
                  ["<d-p>"] = {"inspect", mode = { "n", "i" }},
                  ["<d-.>"] = {"explorer_focus", mode = {"n", "i"}},

                  ["<d-cr>"] = {"tcd_to_item", mode = {"n", "i"}},

                  -- Search from the directory
                  ["<c-/>"] = {"search_from_selected", mode={"n", "i"}},
                  ["<D-/>"] = {"search_from_selected", mode={"n", "i"}},

                  ["<d-z>"] = {"add_to_zoxide", mode = {"n", "i"}},
                  ["<c-z>"] = {"add_to_zoxide", mode = {"n", "i"}},
                  ["z"] = {"add_to_zoxide", mode = {"n"}},
                }
              },
              list = {
                keys = {
                  -- toggle git only
                  ["S"] = { "toggle_only_git", mode = { "n" } },
                  ["<C-S>"] = { "toggle_only_git", mode = { "n", "i" } },
                  ["<D-S>"] = { "toggle_only_git", mode = { "n", "i" } },

                  ["<c-p>"] = {"inspect", mode = { "n", "i" }},
                  ["<d-p>"] = {"inspect", mode = { "n", "i" }},
                  ["p"] = "inspect",

                  ["<d-cr>"] = {"tcd_to_item", mode = {"n", "i"}},

                  -- Search from the directory
                  ["<c-/>"] = {"search_from_selected", mode={"n", "i"}},
                  ["<D-/>"] = {"search_from_selected", mode={"n", "i"}},

                  ["<d-z>"] = {"add_to_zoxide", mode = {"n", "i"}},
                  ["<c-z>"] = {"add_to_zoxide", mode = {"n", "i"}},
                  ["z"] = {"add_to_zoxide", mode = {"n"}},
                }
              },
            }
          },
          buffers = {
            win = {
              input = {
                keys = {
                  -- we won't use dd in input buffer here.
                  -- ["d"] = {"bufdelete", mode={"n"}},

                  ["<c-x>"] = {"edit_split", mode={"n", "i"}},
                  ["<d-x>"] = {"edit_split", mode={"n", "i"}},
                  ["<c-s-x>"] = {"edit_vsplit", mode={"n", "i"}},
                  ["<d-s-x>"] = {"edit_vsplit", mode={"n", "i"}},
                  ["<d-bs>"] = {"bufdelete", mode={"n", "i"}},
                  ["<c-bs>"] = {"bufdelete", mode={"n", "i"}},
                }
              }
            }
          },
          -- FIXME: When left input line and goes back, the buffer will lose focus.
          zoxide = {
            layout = { preset = "vscode", preview = false },
            -- By default, zoxide only changes the current tab cwd.
            confirm = "zoxide_lcd",
            actions = {
              zoxide_tcd = function (picker, item)
                picker:close()
                vim.cmd('silent !zoxide add "' .. item._path .. '"')
                vim.cmd.tcd(item._path)
                vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
              end,
              zoxide_lcd = function(picker, item)
                vim.cmd('silent !zoxide add "' .. item._path .. '"')
                picker:close()
                Snacks.picker.actions.lcd(_, item)
                vim.print_silent("Win pwd: " .. vim.fn.getcwd())
              end,
              remove_from_zoxide = function(_, item)
                vim.cmd('silent !zoxide remove "' .. item._path .. '"')
                vim.notify("Path " .. item._path .. " removed from zoxide record.", vim.log.levels.INFO)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
                  ["t"] = {"new_tab_here", mode={"n"}},

                  ["<c-cr>"] = {"zoxide_tcd", mode={"n", "i"}},
                  ["<d-cr>"] = {"zoxide_tcd", mode={"n", "i"}},

                  -- Search from the directory
                  ["<c-/>"] = {"search_from_selected", mode={"n", "i"}},
                  ["<D-/>"] = {"search_from_selected", mode={"n", "i"}},

                  ["<d-bs>"] = {"remove_from_zoxide", mode={"n", "i"}},
                  ["<c-bs>"] = {"remove_from_zoxide", mode={"n", "i"}},

                  ["v"] = {"v_new_win_here", mode={"n"}},
                  ["x"] = {"x_new_win_here", mode={"n"}},
                  ["<c-v>"] = {"v_new_win_here", mode={"n", "i"}},
                  ["<c-s-x>"] = {"v_new_win_here", mode={"n", "i"}},
                  ["<c-x>"] = {"x_new_win_here", mode={"n", "i"}},
                  ["<d-v>"] = {"v_new_win_here", mode={"n", "i"}},
                  ["<d-s-x>"] = {"v_new_win_here", mode={"n", "i"}},
                  ["<d-x>"] = {"x_new_win_here", mode={"n", "i"}},
                }
              }
            }
          },
          command_history = {
            confirm = "modify",
            actions = {
              execute_without_modification = function (picker, item)
                local cmd;
                if vim.fn.mode() == "i" then
                  cmd = "<esc>:" .. item.cmd
                elseif vim.fn.mode() == "n" then
                  cmd = ":" .. item.cmd
                end
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd .. "<cr>", true, false, true), "n", false)
                picker:close()
              end,
              modify = function (picker, item)
                local cmd;
                if vim.fn.mode() == "i" then
                  cmd = "<esc>:" .. item.cmd
                elseif vim.fn.mode() == "n" then
                  cmd = ":" .. item.cmd
                end
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), "n", false)
                picker:close()
              end
            },
            win = {
              input = {
                keys = {
                  ["<C-CR>"] = { "execute_without_modification", mode = {"n", "i"} },
                  ["<D-CR>"] = { "execute_without_modification", mode = {"n", "i"} }
                }
              },
            }
          }
        }
      }
    },
    -- No need for now. Now use nvim build in * to navigate.
    -- keys = {
    --   { "]]", function() require("snacks").words.jump(vim.v.count1) end, desc = "Next Reference" },
    --   { "[[", function() require("snacks").words.jump(-vim.v.count1) end, desc = "Prev Reference" },
    -- },
  },

  -- Trouble:	diagnostic plugin.
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
    opts = { use_diagnostic_signs = true },
  },

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- {
      --   "<leader>ff",
      --   "<cmd>Telescope find_files no_ignore=false<CR>",
      --   mode = { "n" },
      -- },

      -- files
      { "<leader>fe", false },
      { "<leader>ff", false },
      { "<leader>fb", false },
      { "<leader>fc", false },
      { "<leader>fo", false },

      -- Symbols
      { "<leader>ss", false },
      { "<leader>sS", false },
      { "<leader>sk", false },

      -- Command
      { "<leader>sc", false },
      { "<leader>sC", false },

      -- LSP.
      { "gy", false },
      { "gd", false },
      { "gi", false },
      { "gr", false },

      { "<leader>fh", false },

      -- Search
      { "<leader>/", false },
      -- { "<leader>/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      -- {
      --   "<leader>ss",
      --   "<cmd>lua require(\"telescope.builtin\").lsp_document_symbols()<cr>",
      --   mode = { "n" },
      --   desc = "Navigate symbols in buffer.",
      -- },
      -- migrate from lsp_dynamic_workspace_symbols, which can't use tag search :object:
      -- {
      --   "<leader>sS",
      --   "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
      --   mode = { "n" },
      --   desc = "Navigate symbols in the Workspace.",
      -- },
      -- {
      --   "<leader>sS",
      --   "\"zy:Telescope lsp_dynamic_workspace_symbols default_text=<C-r>z<cr>",
      --   mode = { "v" },
      --   desc = "Navigate symbols in the Workspace.",
      -- },
    },
    -- keys = {
    -- add a keymap to browse plugin files
    -- stylua: ignore
    -- {
    --	 "<leader>fp",
    --	 function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
    --	 desc = "Find Plugin File",
    -- },
    -- },
    dependencies = {
      -- {
        -- "nvim-telescope/telescope-live-grep-args.nvim",
        -- version = "^1.0.0",
        -- This will not install any breaking changes.
        -- For major updates, this must be adjusted manually.
      -- },
      -- {
      --   "nvim-telescope/telescope-fzf-native.nvim",
      -- }
    },
    -- change some options
    opts = {
      defaults = {
        wrap_results = true,
        layout_strategy = "vertical",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
        file_ignore_patterns = {
          "%.o",
          "%.obj",
          "%.a",
          "%.lib",
          "%.dll",
          "%.exe",
          "%.pdb",
          "%.sln",
          "%.vcxproj",
          "Session.vim",
        },
        mappings = {
          -- i = { ["<c-t>"] = require("trouble.sources.telescope").open},
          -- n = { ["<c-t>"] = require("trouble.sources.telescope").open },
        }
      }
    },
  },
  -- {
  --   'nvim-telescope/telescope-fzf-native.nvim',
  --   build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
  --   config = function ()
  --     -- To get fzf loaded and working with telescope, you need to call
  --     -- load_extension, somewhere after setup function:
  --     require('telescope').load_extension('fzf')
  --   end
  -- },
  --[[{
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
      require('dashboard').setup {
        theme = 'hyper',
        config = {
          week_header = {
            enable = true,
          },
          project = { enable = true, limit = 8, icon = 'your icon', label = '', action = 'Telescope find_files cwd=' },
          mru = { limit = 10, icon = 'your icon', label = '', cwd_only = false },
          shortcut = {
            { desc = 'ó°?? Update', group = '@property', action = 'Lazy update', key = 'u' },
            {
              icon = '??? ',
              icon_hl = '@variable',
              desc = 'Files',
              group = 'Label',
              action = 'Telescope find_files',
              key = 'f',
            },
            {
              desc = '??? Apps',
              group = 'DiagnosticHint',
              action = 'Telescope app',
              key = 'a',
            },
            {
              desc = 'î¬? dotfiles',
              group = 'Number',
              action = 'Telescope dotfiles',
              key = 'd',
            },
          },
        },
      }
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } }
  },]]
  {
    "okuuva/auto-save.nvim",
    event = { "InsertLeave", "TextChanged" },
    config = function()
      require("auto-save").setup({
        trigger_events = {
          defer_save = {
            "InsertLeave",
            "TextChanged",
            {"TextChangedP", pattern = "*.md"},
            {"TextChangedI", pattern = "*.md"}
          },
        },
        -- debounce_delay = 500,
      })
    end,
  },
  {
    "kawre/leetcode.nvim",
    cmd = "Leet",

    build = ":TSUpdate html",
    dependencies = {
      -- "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim", -- required by telescope
      "MunifTanjim/nui.nvim",

      -- optional
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      lang = "python3",
      cn = {
        enabled = true,
        translator = true,
        translate_problems = true,
      },
      plugins = {
        non_standalone = true,
      }
    },
  },
  {
    "cohama/lexima.vim"
  },
  {
    "gbprod/yanky.nvim",
    keys = {
      {
        "<leader>yy",
        mode = {"n", "v"},
        function()
          local current_mode = vim.fn.mode()
          if current_mode == "v" or current_mode == "V" or current_mode == "C-V" then
            vim.g.__local_is_visual_mode_before_yanky_picker = true
          end
          Snacks.picker.yanky()
        end,
        desc = "Yanky ring history picker.",
      }
    },
    dependencies = { "folke/snacks.nvim" },
    opts = function ()
      local storage = "shada"
      if vim.g._resource_executable_sqlite then
        storage = "sqlite"
      end
      return {
        ring = {
          history_length = 1000,
          storage = storage,
          sync_with_numbered_registers = false,
          -- Ignroe all by default.
          ignore_registers = { "\"" }
        },
        -- I prever highlight to be done by nvim itself.
        highlight = {
          on_put = false,
          on_yank = false,
          timer = 500,
        },
        system_clipboard = {
          sync_with_ring = false,
          clipboard_register = nil,
        },
      }
    end
  }
}
