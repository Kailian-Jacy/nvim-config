# Copyright (c) 2024 nixCats migration for Kailian-Jacy/nvim-config
# Based on nixCats fresh template (github:BirdeeHub/nixCats-nvim)
#
# nixCats Nix flake skeleton for wrapping the existing Lua config (config.nvim/)
# with Nix-provided dependencies, plugins, LSPs, and tools.
#
# References:
#   :help nixCats.flake
#   https://nixcats.org/nixCats_format.html
#   https://github.com/BirdeeHub/nixCats-nvim/tree/main/templates/fresh

{
  description = "Kailian-Jacy/nvim-config wrapped with nixCats";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixCats.url = "github:BirdeeHub/nixCats-nvim";

    # ── Plugins not in nixpkgs ──────────────────────────────────────────
    # Convention: "plugins-<name>" so utils.standardPluginOverlay picks
    # them up as pkgs.neovimPlugins.<name> automatically.

    # Forks (must use specific repos, NOT nixpkgs versions)
    "plugins-terminal-nvim" = {
      url = "github:Kailian-Jacy/terminal.nvim";
      flake = false;
    };
    "plugins-persistent-breakpoints-nvim" = {
      url = "github:Kailian-Jacy/persistent-breakpoints.nvim";
      flake = false;
    };
    "plugins-bookmarks-nvim" = {
      url = "github:LintaoAmons/bookmarks.nvim";
      flake = false;
    };

    # Plugins genuinely absent from nixpkgs
    "plugins-auto-indent-nvim" = {
      url = "github:vidocqh/auto-indent.nvim";
      flake = false;
    };
    "plugins-cmp-async-path" = {
      url = "github:FelipeLema/cmp-async-path";
      flake = false;
    };
    "plugins-gp-nvim" = {
      url = "github:Robitx/gp.nvim";
      flake = false;
    };
    "plugins-local-highlight-nvim" = {
      url = "github:tzachar/local-highlight.nvim";
      flake = false;
    };
    "plugins-vimade" = {
      url = "github:TaDaa/vimade";
      flake = false;
    };
    "plugins-visual-surround-nvim" = {
      url = "github:NStefan002/visual-surround.nvim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixCats, ... }@inputs: let
    inherit (nixCats) utils;
    luaPath = "${./config.nvim}";
    forEachSystem = utils.eachSystem nixpkgs.lib.platforms.all;

    extra_pkg_config = {
      allowUnfree = true; # for copilot, codelldb, etc.
    };

    # ---------------------------------------------------------------------------
    # Overlays
    # ---------------------------------------------------------------------------
    dependencyOverlays = [
      # Auto-converts all "plugins-<name>" inputs → pkgs.neovimPlugins.<name>
      (utils.standardPluginOverlay inputs)
    ];

    # ---------------------------------------------------------------------------
    # Category Definitions
    # ---------------------------------------------------------------------------
    categoryDefinitions = { pkgs, settings, categories, extra, name, mkPlugin, ... }@packageDef: let
      # ── Local plugin: nvim-runner ───────────────────────────────────────
      nvim-runner = pkgs.vimUtils.buildVimPlugin {
        pname = "nvim-runner";
        version = "local";
        src = ./nvim-runner;
      };
    in {

      # ── Runtime dependencies (on PATH inside Neovim) ────────────────────
      lspsAndRuntimeDeps = {
        general = with pkgs; [
          ripgrep
          fd
          fzf
          git
          curl
          gcc           # needed for treesitter grammar compilation (fallback)
          gnumake
          tree-sitter
          sqlite        # sqlite.lua runtime dependency
        ];
        ai = with pkgs; [
          nodejs        # for copilot.vim, avante.nvim, etc.
        ];
        lsp = with pkgs; [
          lua-language-server
          rust-analyzer
          gopls
          pyright
          ruff                    # linter + formatter
          clang-tools             # provides clangd (and clang-format)
          nil                     # Nix LSP
          vscode-langservers-extracted  # JSON/HTML/CSS/ESLint language servers
          yaml-language-server
          taplo                   # TOML LSP
          cmake-language-server
          checkmake               # Makefile linter
        ];
        formatters = with pkgs; [
          stylua
          gofumpt
          gotools                 # provides goimports
          nixfmt-rfc-style
          nixpkgs-fmt
          # clang-tools already in lsp (provides clang-format)
          python3Packages.cmakelang  # cmake-format + cmake-lint
          python3Packages.black
          # rustfmt comes with the Rust toolchain
          fixjson
          python3Packages.xmlformatter
          shfmt
          gomodifytags
          impl                    # Go interface implementation generator
        ];
        linters = with pkgs; [
          nodePackages.jsonlint
          # cmakelang already in formatters (provides cmake-lint)
        ];
        debug = with pkgs; [
          delve                     # Go debugger
          python3Packages.debugpy   # Python debug adapter
        ];
      };

      # ── Startup plugins (always loaded) ─────────────────────────────────
      # All plugins go into startupPlugins so they sit on the rtp.
      # lazy.nvim (also on rtp) still orchestrates lazy-loading, config()
      # calls, and event/cmd/keys triggers from the Lua specs.
      startupPlugins = {
        core = with pkgs.vimPlugins; [
          # ── Plugin manager (kept for lazy-loading orchestration) ──────
          lazy-nvim

          # ── Completion framework ─────────────────────────────────────
          nvim-cmp
          cmp-nvim-lsp
          cmp-nvim-lsp-signature-help
          cmp-buffer
          cmp-path
          cmp-cmdline
          cmp-git
          cmp_luasnip
          cmp-cmdline-history      # was flake input, exists in nixpkgs
          cmp-under-comparator     # was flake input, exists in nixpkgs
          cmp_yanky                # was flake input, exists in nixpkgs
          luasnip
          friendly-snippets
          lspkind-nvim

          # ── LSP ──────────────────────────────────────────────────────
          nvim-lspconfig
          lazydev-nvim
          inc-rename-nvim

          # ── Treesitter ───────────────────────────────────────────────
          # withAllGrammars bundles pre-compiled grammars → no cc needed
          (nvim-treesitter.withAllGrammars)
          nvim-treesitter-textobjects

          # ── UI ───────────────────────────────────────────────────────
          lualine-nvim
          nvim-web-devicons
          noice-nvim
          nui-nvim
          indent-blankline-nvim
          todo-comments-nvim
          trouble-nvim
          dracula-nvim
          rainbow-delimiters-nvim
          nvim-hlslens
          snacks-nvim              # was flake input, exists in nixpkgs
          render-markdown-nvim     # was flake input, exists in nixpkgs
          nvim-scrollbar           # was flake input, exists in nixpkgs
          bigfile-nvim             # was flake input, exists in nixpkgs

          # ── Git ──────────────────────────────────────────────────────
          gitsigns-nvim
          diffview-nvim
          gitlinker-nvim
          vim-signify

          # ── Editing ─────────────────────────────────────────────────
          conform-nvim
          nvim-lint
          nvim-ufo
          promise-async
          yanky-nvim
          copilot-vim
          plenary-nvim
          sqlite-lua
          lexima-vim               # was flake input, exists in nixpkgs
          auto-save-nvim           # was flake input, exists in nixpkgs
          bufjump-nvim             # was flake input, exists in nixpkgs
          guihua-lua               # was flake input, exists in nixpkgs

          # ── DAP / Debugging ─────────────────────────────────────────
          nvim-dap
          nvim-dap-python
          nvim-dap-virtual-text
          nvim-dap-view            # was flake input, exists in nixpkgs
          nvim-nio
          one-small-step-for-vimkind

          # ── Language-specific ────────────────────────────────────────
          rustaceanvim
          go-nvim
          crates-nvim
          venv-selector-nvim
          leetcode-nvim            # was flake input, exists in nixpkgs
          avante-nvim

          # ── Task / Runner ────────────────────────────────────────────
          overseer-nvim
          vim-startuptime

          # ── Misc ────────────────────────────────────────────────────
          obsidian-nvim
          aerial-nvim
          mason-nvim               # kept for non-Nix fallback awareness
        ];

        # ── Plugins from flake inputs (forks / not in nixpkgs) ────────
        fromInputs = with pkgs.neovimPlugins; [
          # Forks
          terminal-nvim                # Kailian-Jacy/terminal.nvim
          persistent-breakpoints-nvim  # Kailian-Jacy/persistent-breakpoints.nvim
          bookmarks-nvim               # LintaoAmons/bookmarks.nvim

          # Not in nixpkgs
          auto-indent-nvim
          cmp-async-path
          gp-nvim
          local-highlight-nvim
          vimade
          visual-surround-nvim
        ];

        # ── Local plugins ─────────────────────────────────────────────
        localPlugins = [
          nvim-runner
        ];
      };

      # Not using optionalPlugins since lazy.nvim manages lazy-loading
      optionalPlugins = {};

      # ── Shared libraries ────────────────────────────────────────────────
      sharedLibraries = {
        general = with pkgs; [
          sqlite  # sqlite.lua needs libsqlite3.so
        ];
      };

      # ── Environment variables ───────────────────────────────────────────
      environmentVariables = {
        debug = {
          # Expose codelldb extension path so Lua config can find the adapter binary.
          # The extension layout is: <ext>/adapter/codelldb and <ext>/lldb/lib/liblldb.so
          CODELLDB_EXTENSION_PATH = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb";
        };
      };

      # ── Extra Lua packages ──────────────────────────────────────────────
      # leetcode.nvim needs lua-curl, mimetypes, xml2lua
      extraLuaPackages = {
        general = [ (lp: with lp; [ lua-curl mimetypes xml2lua ]) ];
      };
    };

    # ---------------------------------------------------------------------------
    # Package Definitions
    # ---------------------------------------------------------------------------
    packageDefinitions = {
      nvim-nix = { pkgs, name, ... }: {
        settings = {
          wrapRc = true;
          configDirName = "nvim-nix";
          aliases = [ "nvim-nix" ];
          suffix-path = true;
          suffix-LD = true;
          hosts.python3.enable = true;
          hosts.node.enable = true;
        };
        categories = {
          general = true;
          lsp = true;
          formatters = true;
          linters = true;
          debug = true;
          ai = true;
          core = true;
          fromInputs = true;
          localPlugins = true;
        };
      };
    };

    defaultPackageName = "nvim-nix";

  in

  # ---------------------------------------------------------------------------
  # Outputs
  # ---------------------------------------------------------------------------
  forEachSystem (system: let
    nixCatsBuilder = utils.baseBuilder luaPath {
      inherit nixpkgs system dependencyOverlays extra_pkg_config;
    } categoryDefinitions packageDefinitions;
    defaultPackage = nixCatsBuilder defaultPackageName;
    pkgs = import nixpkgs { inherit system; };
  in {
    packages = utils.mkAllWithDefault defaultPackage;

    devShells = {
      default = pkgs.mkShell {
        name = defaultPackageName;
        packages = [ defaultPackage ];
        inputsFrom = [ ];
        shellHook = ''
          echo "nixCats neovim (${defaultPackageName}) is available"
        '';
      };
    };
  }) // (let
    nixosModule = utils.mkNixosModules {
      moduleNamespace = [ defaultPackageName ];
      inherit defaultPackageName dependencyOverlays luaPath
        categoryDefinitions packageDefinitions extra_pkg_config nixpkgs;
    };
    homeModule = utils.mkHomeModules {
      moduleNamespace = [ defaultPackageName ];
      inherit defaultPackageName dependencyOverlays luaPath
        categoryDefinitions packageDefinitions extra_pkg_config nixpkgs;
    };
  in {
    overlays = utils.makeOverlays luaPath {
      inherit nixpkgs dependencyOverlays extra_pkg_config;
    } categoryDefinitions packageDefinitions defaultPackageName;

    nixosModules.default = nixosModule;
    homeModules.default = homeModule;

    inherit utils nixosModule homeModule;
    inherit (utils) templates;
  });
}
