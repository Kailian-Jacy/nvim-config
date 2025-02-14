-- since this is just an example spec, don't actually load anything here and return an empty spec
-- stylua: ignore
-- if true then return {} end

-- every spec file under the "plugins" directory will be loaded automatically by lazy.nvim
--
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enabled LazyVim plugins
-- * override the configuration of LazyVim plugins
return {
  -- Disable some of the builtin plugins.
  {
    "LazyVim/LazyVim",
    version = "12.44.1",
    opts = {
      colorscheme = "dracula",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "HiPhish/rainbow-delimiters.nvim" },
    opts = function(_, opts)
      opts.rainbow = {
        enable = true,
        query = "rainbow-delimiters",
        strategy = require("rainbow-delimiters").strategy.global,
      }
      opts.ensure_installed = {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "rust",
        "go",
        "vim",
        "yaml",
        "json",
        "json5",
      }
      opts.indent = {
        disable = true,
      }
    end,
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    dependencies = {
      "folke/todo-comments.nvim",
      config = function()
          require("todo-comments").setup({})
      end,
    },
    keys = {
      { "<leader>.", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>.", function() Snacks.picker.grep_buffers({ search = vim.g.function_get_selected_content() }) end, desc = "Grep Open Buffers", mode = {"v"} },

      -- Search
      -- { "<leader>/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>/", function() Snacks.picker.grep({ search = vim.g.function_get_selected_content() }) end, desc = "Grep", mode = "v" },
      { "<leader>ll", function() Snacks.picker.lines() end, desc = "Line inspect" },
      { "<leader>ll", function() Snacks.picker.lines({ pattern = vim.g.function_get_selected_content() }) end, desc = "Line inspect", mode = "v"},

      -- File browsing.
      { "<leader>fe", function() Snacks.explorer() end, desc = "File Explorer" },
      { "<leader>fe", function() Snacks.explorer({ pattern = vim.g.function_get_selected_content() }) end, desc = "File Explorer", mode = "v" },
      { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      { "<leader>ff", function() Snacks.picker.smart({ pattern = vim.g.function_get_selected_content() }) end, desc = "Smart Find Files", mode = "v" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>fo", function() Snacks.picker.recent() end, desc = "Recent" },

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
      { "<leader>tt", function() Snacks.picker.resume() end, desc = "Resume" },

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
      bigfile = { enabled = false },
      dashboard = { enabled = false },
      explorer = {
        enabled = true
      },
      -- indent = { enabled = false },
      input = { enabled = false },
      indent = { enabled = false },
      notify = { enabled = false },
      notifier = { enabled = false },
      quickfile = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false },
      -- statuscolumn = { enabled = false },
      words = { enabled = false },
      picker = {
        layout = { preset = "dropdown" },
        win = {
          input = {
            keys = {
              ["<c-x>"] = {"edit_split", mode = {"n", "i"}},
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},

              -- Searching from the directory.
              ["/"] = {"search_here", mode={"n"}},
              ["<c-/>"] = {"search_here", mode={"n", "i"}},
              ["<D-/>"] = {"search_here", mode={"n", "i"}},

              -- Window switching
              ["<C-w>"] = {"to_preview", mode = {"n", "i"}},
              ["w"] = "to_preview",

              -- ["<C-w>"] = {"cycle_win", mode = {"n", "i"}},
              ["<D-o>"] = {"toggle_maximize", mode = { "n", "i" }},
              ["<C-o>"] = {"toggle_maximize", mode = { "n", "i" }},
              ["o"] = "toggle_maximize",
              ["x"] = "edit_split",
              ["v"] = "edit_vsplit",
              ["p"] = "inspect",
            }
          },
          list = {
            keys = {
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},

              -- Search from the directory
              ["/"] = {"search_here", mode={"n"}},
              ["<c-/>"] = {"search_here", mode={"n", "i"}},
              ["<D-/>"] = {"search_here", mode={"n", "i"}},

              -- Window switching
              ["<C-w>"] = {"cycle_win", mode = {"n", "i"}},
              ["w"] = "cycle_win",

              ["o"] = "toggle_maximize",
              ["x"] = "edit_split",
              ["v"] = "edit_vsplit",
              ["p"] = "inspect",
              ["A"] = "toggle_focus",
              ["a"] = "toggle_focus",
            }
          },
          preview = {
            keys = {
              ["<C-Tab>"] = {"cycle_win", mode = {"n", "i"}},
              ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},

              -- Window switching
              ["<C-w>"] = {"to_input", mode = {"n", "i"}},
              ["w"] = "to_input",

              ["o"] = "toggle_maximize",
              ["x"] = "edit_split",
              ["v"] = "edit_vsplit",
              ["p"] = "inspect",
              ["A"] = "toggle_focus",
              ["a"] = "toggle_focus",
            }
          }
        },
        actions = {
          test = function(self, item)
            vim.print("triggered")
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
            Snacks.picker.actions.tcd(_, item)
            vim.print_silent("Tab pwd: " .. vim.fn.getcwd())
            item.dir = item.dir or false
            -- If possible, open the file there.
            if not item.dir then
              vim.cmd("e " .. item._path)
            end
          end,
          v_new_win_here = function (_, item)
            vim.cmd[[ vsplit ]]
            vim.cmd.lcd(item._path)
            -- Snacks.picker.actions.lcd(_, item)
          end,
          x_new_win_here = function (_, item)
            vim.cmd[[ split ]]
            vim.cmd.lcd(item._path)
            -- Snacks.picker.actions.lcd(_, item)
          end,
          search_here = function(picker, item)
            item.dir = item.dir or false
            if not item.dir then
              vim.print_silent("not directory. Could not search here.")
              return
            end
            vim.schedule(function()
              picker:close()
              Snacks.picker.grep({
                cwd = item._path
              })
            end)
          end
        },
        sources = {
          buffers = {
            win = {
              preview = {
                keys = {
                  -- FIXME: Not working for now. Seems like it's acting like normal buffer.
                  ["<C-w>"] = {"cycle_win", mode = {"n", "i"}},
                }
              },
              input = {
                keys = {
                  ["<c-x>"] = { "edit_split", mode = { "n", "i" } },
                  ["<c-d>"] = { "bufdelete", mode = { "n", "i" } },
                }
              }
            }
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
                  ["<c-t>"] = { "go_to_if_possible" , mode={"n", "i"}}
                }
              }
            }
          },
          explorer = {
            -- your explorer picker configuration comes here
            -- or leave it empty to use the default settings
            layout = { preset = "dropdown", preview = true },
            actions = {
              move_pwd_here = function (_, item)
                vim.cmd.lcd(item._path)
              end,
            },
            diagnostics_open = true,
            focus = "input",
            auto_close = true,
            win = {
              input = {
                keys = {
                  ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
                  ["<c-x>"] = {"edit_split", mode={"n", "i"}},
                  ["x"] = {"edit_split", mode={"n"}},
                  ["v"] = {"edit_vsplit", mode={"n"}},
                  ["t"] = {"edit_vsplit", mode={"n"}},
                }
              },
              preview = {
                keys = {
                  ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
                  ["<c-x>"] = {"edit_split", mode={"n", "i"}},
                  ["<c-/>"] = {"search_here", mode={"n"}},
                  ["x"] = {"edit_split", mode={"n"}},
                  ["v"] = {"edit_vsplit", mode={"n"}},
                }
              },
              list = {
                keys = {
                  ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
                  ["<c-x>"] = {"edit_split", mode={"n", "i"}},
                  ["x"] = {"edit_split", mode={"n"}},
                  ["v"] = {"edit_vsplit", mode={"n"}},
                  ["/"] = {"search_here", mode={"n"}},
                  ["<c-/>"] = {"search_here", mode={"n"}},
                }
              }
            }
          },
          zoxide = {
            layout = { preset = "vscode", preview = false },
            win = {
              input = {
                keys = {
                  -- ["<c-t>"] = {"test", mode={"n", "i"}},
                  ["<c-t>"] = {"new_tab_here", mode={"n", "i"}},
                  -- FIXME: They won't work for now.
                  --
                  ["<c-x>"] = {"x_new_win_here", mode={"n", "i"}},
                  ["<c-v>"] = {"v_new_win_here", mode={"n", "i"}},
                  ["<c-X>"] = {"v_new_win_here", mode={"n", "i"}},
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
  -- {
  --   "gbprod/yanky.nvim",
  --   dependencies = {
  --     { "kkharji/sqlite.lua" }
  --   },
  --   opts = {
  --     ring = { storage = "sqlite" },
  --   },
  -- }
}
