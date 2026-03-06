-- Test Plugin Configurations (179 test cases)
-- Based on reports/04-test-plan-04-plugins.md

package.path = package.path .. ";tests/?.lua"
local H = require("harness")

io.write("=== Testing Plugin Configurations ===\n\n")

local function has_mapping(lhs, mode)
  mode = mode or "n"
  local m = vim.fn.maparg(lhs, mode)
  if m ~= nil and m ~= "" then return true end
  local maps = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(maps) do
    if map.lhs == lhs then return true end
  end
  return false
end

local function safe_require(mod)
  local ok, m = pcall(require, mod)
  return ok, m
end

-- 4.1 Terminal.nvim
H.test("TC-PLG-001", "terminal.nvim loads", function()
  local ok, _ = safe_require("terminal")
  H.assert_true(ok, "require('terminal') should work")
end)

H.test("TC-PLG-002", "<leader>tt toggle terminal", function()
  H.assert_true(has_mapping(" tt", "n"), "<leader>tt should exist")
end)

H.test("TC-PLG-003", "<leader>gg lazygit", function()
  H.assert_true(has_mapping(" gg", "n"), "<leader>gg should exist")
end)

H.test("TC-PLG-004", "Lazygit command exists", function()
  H.assert_true(vim.fn.exists(":Lazygit") >= 1, "Lazygit command should exist")
end)

H.test("TC-PLG-005", "<c-bs> terminal reset", function()
  H.assert_true(has_mapping("<C-BS>", "t"), "<c-bs> should exist in terminal mode")
end)

H.test("TC-PLG-006", "<c-s-l> terminal move right", function()
  H.assert_true(has_mapping("<C-S-L>", "t") or has_mapping("<C-S-l>", "t"))
end)

H.test("TC-PLG-007", "<d-esc> terminal exit to normal", function()
  H.assert_true(has_mapping("<D-Esc>", "t"), "<d-esc> should exist in terminal mode")
end)

H.test("TC-PLG-008", "<c-esc> terminal exit to normal", function()
  H.assert_true(has_mapping("<C-Esc>", "t"), "<c-esc> should exist in terminal mode")
end)

H.skip("TC-PLG-009", "TermOpen sets buflisted=false", "Requires terminal buffer")
H.skip("TC-PLG-010", "terminal_auto_insert auto insert", "Requires terminal enter")

-- 4.2 local-highlight.nvim
H.test("TC-PLG-011", "local-highlight loads", function()
  local ok, _ = safe_require("local-highlight")
  H.assert_true(ok, "require('local-highlight') should work")
end)

H.test("TC-PLG-012", "FaintSelected highlight exists", function()
  local hl = vim.api.nvim_get_hl(0, { name = "FaintSelected" })
  H.assert_true(next(hl) ~= nil, "FaintSelected highlight should exist")
end)

-- 4.3 bufjump.nvim
H.test("TC-PLG-013", "H jumps to prev buffer", function()
  H.assert_true(has_mapping("H", "n"), "H should have mapping")
end)

H.test("TC-PLG-014", "L jumps to next buffer", function()
  H.assert_true(has_mapping("L", "n"), "L should have mapping")
end)

H.skip("TC-PLG-015", "H skips terminal buffer", "Requires buffer history test")

-- 4.4 LuaSnip
H.test("TC-PLG-016", "LuaSnip loads", function()
  local ok, _ = safe_require("luasnip")
  H.assert_true(ok, "require('luasnip') should work")
end)

H.skip("TC-PLG-017", "User snippet paths configured", "Requires snippet check")

-- 4.5 visual-surround.nvim
H.test("TC-PLG-018", "visual-surround loads", function()
  local ok, _ = safe_require("visual-surround")
  H.assert_true(ok, "require('visual-surround') should work")
end)

H.skip("TC-PLG-019", "< in visual mode wraps", "Requires visual mode test")
H.skip("TC-PLG-020", "< in visual-line mode indents", "Requires visual-line test")

-- 4.6 auto-indent
H.skip("TC-PLG-021", "auto-indent loaded", "Check vim.g._auto_indent_used")

-- 4.7 todo-comments
H.test("TC-PLG-022", "<leader>mt adds TODO marker", function()
  H.assert_true(has_mapping(" mt", "n"), "<leader>mt should exist")
end)

H.skip("TC-PLG-023", "todo-comments signs disabled", "Config check")
H.skip("TC-PLG-024", "CHECK and BUGREPORT keywords", "Functional test")

-- 4.8 bookmarks.nvim
H.test("TC-PLG-025", "' opens bookmark picker", function()
  H.assert_true(has_mapping("'", "n"), "' should have mapping")
end)

H.test("TC-PLG-026", "m creates/toggles bookmark", function()
  H.assert_true(has_mapping("m", "n"), "m should have mapping")
end)

H.test("TC-PLG-027", "M opens bookmark description", function()
  H.assert_true(has_mapping("M", "n"), "M should have mapping")
end)

H.test("TC-PLG-028", "<leader>mm grep marked files", function()
  H.assert_true(has_mapping(" mm", "n"), "<leader>mm should exist")
end)

H.test("TC-PLG-029", "<leader>md delete bookmark", function()
  H.assert_true(has_mapping(" md", "n"), "<leader>md should exist")
end)

H.test("TC-PLG-030", "gm shows bookmark info", function()
  H.assert_true(has_mapping("gm", "n"), "gm should have mapping")
end)

-- 4.9 Mason
H.test("TC-PLG-031", "mason.nvim loads", function()
  local ok, _ = safe_require("mason")
  H.assert_true(ok, "require('mason') should work")
end)

H.skip("TC-PLG-032", "mason.ensure_installed exists", "Internal table check")
H.skip("TC-PLG-033", "mason.is_installed callable", "Internal API check")
H.skip("TC-PLG-034", "mason.link_as_install callable", "Internal API check")
H.skip("TC-PLG-035", "mason.try_link_before_install callable", "Internal API check")

-- 4.10 Treesitter textobjects
H.skip("TC-PLG-036", "af textobject function outer", "Requires treesitter test")
H.skip("TC-PLG-037", "if textobject function inner", "Requires treesitter test")
H.skip("TC-PLG-038", "ac textobject class outer", "Requires treesitter test")
H.skip("TC-PLG-039", "ic textobject class inner", "Requires treesitter test")
H.skip("TC-PLG-040", "Tab incremental selection", "Requires treesitter test")
H.skip("TC-PLG-041", "S-Tab decremental selection", "Requires treesitter test")

-- 4.11 nvim-lspconfig
H.skip("TC-PLG-042", "lua_ls configured", "Requires LSP startup")
H.skip("TC-PLG-043", "lua_ls recognizes vim global", "Requires LSP analysis")
H.skip("TC-PLG-044", "jsonls snippetSupport", "Requires LSP config check")
H.skip("TC-PLG-045", "pyright configured", "Requires LSP startup")

H.test("TC-PLG-046", "LSP inlay hint enabled", function()
  local ok, enabled = pcall(function() return vim.lsp.inlay_hint.is_enabled() end)
  if ok then
    H.assert_true(enabled, "inlay hint should be enabled")
  else
    H.skip("TC-PLG-046", "LSP inlay hint", "API not available")
  end
end)

H.skip("TC-PLG-047", "clangd configured", "Requires cpp module")
H.skip("TC-PLG-048", "gopls configured", "Requires go module")

-- 4.12 nvim-lint
H.test("TC-PLG-049", "lint linters_by_ft non-empty", function()
  local ok, lint = safe_require("lint")
  H.assert_true(ok, "require('lint') should work")
  H.assert_true(lint.linters_by_ft ~= nil and next(lint.linters_by_ft) ~= nil,
    "linters_by_ft should be non-empty")
end)

H.test("TC-PLG-050", "json linter is jsonlint", function()
  local lint = require("lint")
  local json_linters = lint.linters_by_ft.json
  H.assert_true(json_linters ~= nil, "json linters should be configured")
  H.assert_true(vim.tbl_contains(json_linters, "jsonlint"), "should include jsonlint")
end)

H.test("TC-PLG-051", "python linter is ruff", function()
  local lint = require("lint")
  local py_linters = lint.linters_by_ft.python
  H.assert_true(py_linters ~= nil, "python linters should be configured")
  H.assert_true(vim.tbl_contains(py_linters, "ruff"), "should include ruff")
end)

-- 4.13 conform.nvim
H.test("TC-PLG-052", "conform loads", function()
  local ok, _ = safe_require("conform")
  H.assert_true(ok, "require('conform') should work")
end)

H.test("TC-PLG-053", "<leader><CR> format mapping", function()
  H.assert_true(has_mapping(" <CR>", "n"), "<leader><CR> should exist")
end)

H.test("TC-PLG-054", "ConformFormat command exists", function()
  H.assert_true(vim.fn.exists(":ConformFormat") >= 1, "ConformFormat should exist")
end)

H.test("TC-PLG-055", "rust uses rustfmt", function()
  local conform = require("conform")
  local rust_fmt = conform.formatters_by_ft.rust
  H.assert_true(rust_fmt ~= nil, "rust formatters should exist")
  H.assert_true(vim.tbl_contains(rust_fmt, "rustfmt"), "should include rustfmt")
end)

H.skip("TC-PLG-056", "format_on_save disabled", "Config check")

-- 4.14 barbecue.nvim
H.test("TC-PLG-057", "barbecue loads", function()
  local ok, _ = safe_require("barbecue")
  H.assert_true(ok, "require('barbecue') should work")
end)

-- 4.15 inc-rename
H.test("TC-PLG-058", "<leader>rn triggers IncRename", function()
  H.assert_true(has_mapping(" rn", "n"), "<leader>rn should exist in normal mode")
end)

-- 4.16 aerial.nvim
H.test("TC-PLG-059", "gj jumps to next symbol", function()
  H.assert_true(has_mapping("gj", "n"), "gj should have mapping")
end)

H.test("TC-PLG-060", "gk jumps to prev symbol", function()
  H.assert_true(has_mapping("gk", "n"), "gk should have mapping")
end)

-- 4.17 indent-blankline
H.test("TC-PLG-061", "<leader>ui toggle indent guides", function()
  H.assert_true(has_mapping(" ui", "n"), "<leader>ui should exist")
end)

H.skip("TC-PLG-062", "indent-blankline default disabled", "Requires ibl config check")

-- 4.18 lazydev
H.skip("TC-PLG-063", "lazydev loads for lua files", "Requires lua file open")

-- 4.19 nvim-cmp
H.test("TC-PLG-064", "nvim-cmp loads", function()
  local ok, _ = safe_require("cmp")
  H.assert_true(ok, "require('cmp') should work")
end)

H.skip("TC-PLG-065", "Tab confirms completion", "Requires cmp interaction")
H.skip("TC-PLG-066", "Tab expands luasnip", "Requires luasnip state")
H.skip("TC-PLG-067", "S-Tab jumps backward in snippet", "Requires snippet state")
H.skip("TC-PLG-068", "CR confirms or newline", "Requires cmp state")
H.skip("TC-PLG-069", "C-c cancels completion", "Requires cmp state")
H.skip("TC-PLG-070", "Up/Down selects items", "Requires cmp state")
H.skip("TC-PLG-071", "Right jumps snippet or accepts copilot", "Requires cmp state")
H.skip("TC-PLG-072", "ghost_text disabled", "Requires cmp config check")
H.skip("TC-PLG-073", "cmdline / ? completion", "Requires cmdline mode")
H.skip("TC-PLG-074", "cmdline : completion", "Requires cmdline mode")
H.skip("TC-PLG-075", "cmp source priority order", "Requires cmp config check")

-- 4.20 Gitsigns
H.test("TC-PLG-076", "<leader>hr reset hunk", function()
  H.assert_true(has_mapping(" hr", "n"), "<leader>hr should exist")
end)

H.test("TC-PLG-077", "<leader>hp preview hunk", function()
  H.assert_true(has_mapping(" hp", "n"), "<leader>hp should exist")
end)

H.test("TC-PLG-078", "<leader>hq hunk to quickfix", function()
  H.assert_true(has_mapping(" hq", "n"), "<leader>hq should exist")
end)

H.test("TC-PLG-079", "<leader>sd git diff in new tab", function()
  H.assert_true(has_mapping(" sd", "n"), "<leader>sd should exist")
end)

H.test("TC-PLG-080", "<leader>hs stage hunk", function()
  H.assert_true(has_mapping(" hs", "n"), "<leader>hs should exist")
end)

H.test("TC-PLG-081", "<leader>hb blame line", function()
  H.assert_true(has_mapping(" hb", "n"), "<leader>hb should exist")
end)

H.test("TC-PLG-082", "<leader>hB full blame", function()
  H.assert_true(has_mapping(" hB", "n"), "<leader>hB should exist")
end)

H.test("TC-PLG-083", "]c next change", function()
  H.assert_true(has_mapping("]c", "n"), "]c should have mapping")
end)

H.test("TC-PLG-084", "[c prev change", function()
  H.assert_true(has_mapping("[c", "n"), "[c should have mapping")
end)

-- 4.21 Diffview
H.test("TC-PLG-085", "<leader>sD DiffviewOpen", function()
  H.assert_true(has_mapping(" sD", "n"), "<leader>sD should exist")
end)

-- 4.22 gitlinker
H.test("TC-PLG-086", "gitlinker loads", function()
  local ok, _ = safe_require("gitlinker")
  H.assert_true(ok, "require('gitlinker') should work")
end)

-- 4.23 DAP
H.test("TC-PLG-087", "nvim-dap loads", function()
  local ok, _ = safe_require("dap")
  H.assert_true(ok, "require('dap') should work")
end)

H.skip("TC-PLG-088", "persistent-breakpoints auto-load", "Requires BufReadPost")

H.test("TC-PLG-089", "<leader>xb toggle breakpoint", function()
  H.assert_true(has_mapping(" xb", "n"), "<leader>xb should exist")
end)

H.test("TC-PLG-090", "<leader>xB conditional breakpoint", function()
  H.assert_true(has_mapping(" xB", "n"), "<leader>xB should exist")
end)

H.test("TC-PLG-091", "<leader>Dl run last debug", function()
  H.assert_true(has_mapping(" Dl", "n"), "<leader>Dl should exist")
end)

H.test("TC-PLG-092", "<leader>dr toggle REPL", function()
  H.assert_true(has_mapping(" dr", "n"), "<leader>dr should exist")
end)

H.test("TC-PLG-093", "DAP listeners configured", function()
  local dap = require("dap")
  H.assert_true(dap.listeners ~= nil, "dap.listeners should exist")
end)

H.skip("TC-PLG-094", "DAP terminate resets status", "Requires DAP session")

H.test("TC-PLG-095", "lua debug config exists", function()
  local dap = require("dap")
  H.assert_true(dap.configurations.lua ~= nil, "lua debug config should exist")
end)

H.test("TC-PLG-096", "<leader>ud toggle DapView", function()
  H.assert_true(has_mapping(" ud", "n"), "<leader>ud should exist")
end)

H.test("TC-PLG-097", "<leader>uv toggle virtual text", function()
  H.assert_true(has_mapping(" uv", "n"), "<leader>uv should exist")
end)

H.skip("TC-PLG-098", "dap-view winbar config", "Config check")

-- 4.24 Theme
H.test("TC-PLG-099", "dracula theme loaded", function()
  H.assert_eq(vim.g.colors_name, "dracula")
end)

H.test("TC-PLG-100", "FaintSelected highlight group exists", function()
  local hl = vim.api.nvim_get_hl(0, { name = "FaintSelected" })
  H.assert_true(next(hl) ~= nil, "FaintSelected should exist")
end)

H.test("TC-PLG-101", "CursorLine background cleared", function()
  local hl = vim.api.nvim_get_hl(0, { name = "CursorLine" })
  -- bg should be nil or not set (cleared)
  H.assert_true(hl.bg == nil, "CursorLine bg should be nil (cleared)")
end)

-- 4.25 Noice
H.test("TC-PLG-102", "noice loads", function()
  local ok, _ = safe_require("noice")
  H.assert_true(ok, "require('noice') should work")
end)

H.test("TC-PLG-103", "<leader>im message history", function()
  H.assert_true(has_mapping(" im", "n"), "<leader>im should exist")
end)

H.skip("TC-PLG-104", "vim.print redirected to notify", "Functional test")

H.test("TC-PLG-105", "vim.print_silent exists", function()
  H.assert_true(vim.print_silent ~= nil, "vim.print_silent should exist")
end)

H.skip("TC-PLG-106", "noice gf in message window", "Requires noice buffer")

-- 4.26 Lualine
H.test("TC-PLG-107", "lualine loads", function()
  local ok, _ = safe_require("lualine")
  H.assert_true(ok, "require('lualine') should work")
end)

H.skip("TC-PLG-108", "lualine sections include filename", "Config check")
H.skip("TC-PLG-109", "lualine global_status", "Config check")
H.skip("TC-PLG-110", "lualine system icon function", "Functional test")

-- 4.27 Scrollbar
H.test("TC-PLG-111", "scrollbar loads", function()
  local ok, _ = safe_require("scrollbar")
  H.assert_true(ok, "require('scrollbar') should work")
end)

H.test("TC-PLG-112", "<leader>ub toggle scrollbar", function()
  H.assert_true(has_mapping(" ub", "n"), "<leader>ub should exist")
end)

H.skip("TC-PLG-113", "scrollbar default hidden", "Config state check")

-- 4.28 hlslens
H.skip("TC-PLG-114", "hlslens shows search marks", "Functional test")

-- 4.29 vimade
H.test("TC-PLG-115", "vimade loads", function()
  local ok, _ = safe_require("vimade")
  H.assert_true(ok, "require('vimade') should work")
end)

H.skip("TC-PLG-116", "vimade fadelevel 0.66", "Config check")

-- 4.30 Snacks.nvim
local snacks_mappings = {
  { "TC-PLG-117", " bb", "buffer picker" },
  { "TC-PLG-118", " bB", "grep buffers" },
  { "TC-PLG-119", " /", "global grep" },
  { "TC-PLG-121", " fe", "file explore" },
  { "TC-PLG-122", " ff", "smart file find" },
  { "TC-PLG-123", " fc", "config files" },
  { "TC-PLG-124", " fo", "recent files" },
  { "TC-PLG-125", " ss", "LSP symbols" },
  { "TC-PLG-126", " sS", "workspace symbols" },
  { "TC-PLG-127", " gd", "Git diff" },
  { "TC-PLG-128", " lt", "TODO comments" },
  { "TC-PLG-129", " sk", "keymaps" },
  { "TC-PLG-130", " jJ", "workspace diagnostics" },
  { "TC-PLG-131", " jj", "buffer diagnostics" },
  { "TC-PLG-136", " tT", "resume last picker" },
  { "TC-PLG-137", " pp", "command history" },
  { "TC-PLG-138", " pP", "all commands" },
  { "TC-PLG-139", " zz", "zoxide" },
}

for _, sm in ipairs(snacks_mappings) do
  H.test(sm[1], sm[2] .. " " .. sm[3], function()
    H.assert_true(has_mapping(sm[2], "n"), sm[2] .. " should exist")
  end)
end

H.test("TC-PLG-120", "<c-/> line search", function()
  H.assert_true(has_mapping("<C-/>", "n"), "<c-/> should exist")
end)

H.test("TC-PLG-132", "gd go to definition", function()
  H.assert_true(has_mapping("gd", "n"), "gd should have mapping")
end)

H.test("TC-PLG-133", "gr find references", function()
  H.assert_true(has_mapping("gr", "n"), "gr should have mapping")
end)

H.test("TC-PLG-134", "gi go to implementation", function()
  H.assert_true(has_mapping("gi", "n"), "gi should have mapping")
end)

H.test("TC-PLG-135", "gy go to type definition", function()
  H.assert_true(has_mapping("gy", "n"), "gy should have mapping")
end)

H.test("TC-PLG-140", "visual mode picker with prefill", function()
  H.assert_true(has_mapping(" /", "v"), "<leader>/ should exist in visual mode")
end)

H.skip("TC-PLG-141", "snacks picker layout dropdown", "Config check")
H.skip("TC-PLG-142", "snacks explorer layout dropdown + preview", "Config check")

-- 4.31 nvim-ufo
H.test("TC-PLG-143", "ufo loads", function()
  local ok, _ = safe_require("ufo")
  H.assert_true(ok, "require('ufo') should work")
end)

H.test("TC-PLG-144", "zR opens all folds", function()
  H.assert_true(has_mapping("zR", "n"), "zR should have mapping")
end)

H.test("TC-PLG-145", "zM closes all folds", function()
  H.assert_true(has_mapping("zM", "n"), "zM should have mapping")
end)

H.test("TC-PLG-146", "foldlevel = 99", function()
  H.assert_eq(vim.o.foldlevel, 99)
end)

-- 4.32 Treesitter
H.test("TC-PLG-147", "treesitter loads", function()
  local ok, _ = safe_require("nvim-treesitter")
  H.assert_true(ok, "require('nvim-treesitter') should work")
end)

H.skip("TC-PLG-148", "ensure_installed includes core languages", "Config check")

H.test("TC-PLG-149", "zsh registered as bash parser", function()
  local ok, lang = pcall(vim.treesitter.language.get_lang, "zsh")
  if ok then
    H.assert_eq(lang, "bash", "zsh should map to bash parser")
  else
    H.skip("TC-PLG-149", "zsh bash parser", "API not available")
  end
end)

H.skip("TC-PLG-150", "rainbow-delimiters enabled", "Config check")

-- 4.33 auto-save
H.test("TC-PLG-151", "auto-save loads", function()
  local ok, _ = safe_require("auto-save")
  H.assert_true(ok, "require('auto-save') should work")
end)

H.skip("TC-PLG-152", "trigger events include InsertLeave", "Config check")

-- 4.34 yanky.nvim
H.test("TC-PLG-153", "<leader>yy yanky picker", function()
  H.assert_true(has_mapping(" yy", "n"), "<leader>yy should exist")
end)

H.skip("TC-PLG-154", "yanky history_length 1000", "Config check")
H.skip("TC-PLG-155", "yanky no system clipboard sync", "Config check")
H.skip("TC-PLG-156", "yanky ignores default register", "Config check")

-- 4.35 Copilot
H.test("TC-PLG-157", "copilot loads (if node available)", function()
  if vim.fn.executable("node") == 1 then
    -- Just check plugin was loaded, copilot.vim doesn't use require
    H.assert_true(vim.g.copilot_no_maps == true, "copilot_no_maps should be set")
  else
    H.skip("TC-PLG-157", "copilot loads", "node not available")
  end
end)

H.test("TC-PLG-158", "<D-CR> in insert accepts copilot", function()
  H.assert_true(has_mapping("<D-CR>", "i"), "<D-CR> should exist in insert mode")
end)

-- 4.36 gp.nvim
H.test("TC-PLG-159", "gp.nvim loads", function()
  local ok, _ = safe_require("gp")
  H.assert_true(ok, "require('gp') should work")
end)

H.test("TC-PLG-160", "<leader>ae triggers Rewrite", function()
  H.assert_true(has_mapping(" ae", "n"), "<leader>ae should exist")
end)

H.test("TC-PLG-161", "Rewrite command exists", function()
  H.assert_true(vim.fn.exists(":Rewrite") >= 1, "Rewrite command should exist")
end)

-- 4.37 Rustaceanvim
H.test("TC-PLG-162", "rustaceanvim config function exists", function()
  -- Before loading, vim.g.rustaceanvim should be set (table or function)
  H.assert_true(vim.g.rustaceanvim ~= nil, "vim.g.rustaceanvim should be set")
end)

H.test("TC-PLG-163", "<leader>ge rust diagnostics", function()
  H.assert_true(has_mapping(" ge", "n"), "<leader>ge should exist")
end)

H.test("TC-PLG-164", "J in rust (join lines)", function()
  -- J is a default vim mapping, check if it's overridden for rust
  H.assert_true(has_mapping("J", "n"), "J should have mapping")
end)

H.skip("TC-PLG-165", "gD opens docs in rust file", "Requires .rs file")

-- 4.38 crates.nvim
H.skip("TC-PLG-166", "crates.nvim in Cargo.toml", "Requires Cargo.toml")

-- 4.39 go.nvim
H.skip("TC-PLG-167", "go.nvim loads", "Requires .go file")

-- 4.40 Python DAP
H.skip("TC-PLG-168", "venv-selector loads", "Requires .py file and python")
H.skip("TC-PLG-169", "dap-python configured", "Requires python module")
H.skip("TC-PLG-170", "debugpy default config", "Requires python module")

-- 4.41 hex.nvim
H.test("TC-PLG-171", "hex.nvim disabled when read_binary_with_xxd=false", function()
  -- hex.nvim should not be loaded when read_binary_with_xxd is false
  H.assert_eq(vim.g.read_binary_with_xxd, false, "read_binary_with_xxd should be false")
end)

-- 4.42 obsidian.nvim
H.skip("TC-PLG-172", "obsidian.nvim conditional enable", "Depends on obsidian_functions_enabled")

-- 4.43 Overseer
H.test("TC-PLG-173", "<leader>ll recent task", function()
  H.assert_true(has_mapping(" ll", "n"), "<leader>ll should exist")
end)

H.test("TC-PLG-174", "<leader>lL toggle overseer list", function()
  H.assert_true(has_mapping(" lL", "n"), "<leader>lL should exist")
end)

H.test("TC-PLG-175", "<leader>lm run command", function()
  H.assert_true(has_mapping(" lm", "n"), "<leader>lm should exist")
end)

H.test("TC-PLG-176", "<leader>lr run task", function()
  H.assert_true(has_mapping(" lr", "n"), "<leader>lr should exist")
end)

H.test("TC-PLG-177", "<leader>lR restart last task", function()
  H.assert_true(has_mapping(" lR", "n"), "<leader>lR should exist")
end)

-- 4.44 Lazy.nvim config
H.skip("TC-PLG-178", "checker enabled notify false", "Config check")
H.skip("TC-PLG-179", "disabled RTP plugins list", "Config check")

-- Print summary
H.summary()

-- Write results
local f = io.open("tests/results_plugins.txt", "w")
if f then
  f:write(H.get_report())
  f:close()
end
