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

    # Plugins not in nixpkgs — use plugins-<name> convention
    # so utils.standardPluginOverlay picks them up automatically.
    "plugins-auto-indent-nvim" = {
      url = "github:vidocqh/auto-indent.nvim";
      flake = false;
    };
    "plugins-auto-save-nvim" = {
      url = "github:okuuva/auto-save.nvim";
      flake = false;
    };
    "plugins-bookmarks-nvim" = {
      url = "github:tomasky/bookmarks.nvim";
      flake = false;
    };
    "plugins-bufjump-nvim" = {
      url = "github:kwkarlwang/bufjump.nvim";
      flake = false;
    };
    "plugins-cmp-async-path" = {
      url = "github:FelipeLema/cmp-async-path";
      flake = false;
    };
    "plugins-cmp-cmdline-history" = {
      url = "github:dmitmel/cmp-cmdline-history";
      flake = false;
    };
    "plugins-cmp-under-comparator" = {
      url = "github:lukas-reineke/cmp-under-comparator";
      flake = false;
    };
    "plugins-cmp_yanky" = {
      url = "github:chrisgrieser/cmp_yanky";
      flake = false;
    };
    "plugins-gp-nvim" = {
      url = "github:Robitx/gp.nvim";
      flake = false;
    };
    "plugins-guihua-lua" = {
      url = "github:ray-x/guihua.lua";
      flake = false;
    };
    "plugins-leetcode-nvim" = {
      url = "github:kawre/leetcode.nvim";
      flake = false;
    };
    "plugins-lexima-vim" = {
      url = "github:cohama/lexima.vim";
      flake = false;
    };
    "plugins-local-highlight-nvim" = {
      url = "github:tzachar/local-highlight.nvim";
      flake = false;
    };
    "plugins-nvim-dap-view" = {
      url = "github:igorlfs/nvim-dap-view";
      flake = false;
    };
    "plugins-nvim-scrollbar" = {
      url = "github:petertriho/nvim-scrollbar";
      flake = false;
    };
    "plugins-terminal-nvim" = {
      url = "github:rebelot/terminal.nvim";
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
    "plugins-bigfile-nvim" = {
      url = "github:LunarVim/bigfile.nvim";
      flake = false;
    };
    "plugins-snacks-nvim" = {
      url = "github:folke/snacks.nvim";
      flake = false;
    };
    "plugins-render-markdown-nvim" = {
      url = "github:MeanderingProgrammer/render-markdown.nvim";
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
      # Auto-converts all inputs-"plugins-<name>" into pkgs.neovimPlugins.<name>
      (utils.standardPluginOverlay inputs)
    ];

    # ---------------------------------------------------------------------------
    # Category Definitions
    # ---------------------------------------------------------------------------
    categoryDefinitions = { pkgs, settings, categories, extra, name, mkPlugin, ... }@packageDef: {

      # ── Runtime dependencies (on PATH inside Neovim) ────────────────────
      lspsAndRuntimeDeps = {
        general = with pkgs; [
          ripgrep
          fd
          fzf
          git
          curl
          gcc
          gnumake
          tree-sitter
          nodejs  # for copilot
        ];
        lsp = with pkgs; [
          lua-language-server
          rust-analyzer
          gopls
          pyright
          ruff
          clangd
          nil  # nix LSP
          nodePackages.vscode-json-languageserver
          yaml-language-server
          taplo  # TOML LSP
        ];
        formatters = with pkgs; [
          stylua
          gofumpt
          gotools          # provides goimports
          nixfmt-rfc-style
        ];
        debug = with pkgs; [
          delve                     # Go debugger
          python3Packages.debugpy   # Python debug adapter
        ] ++ (with pkgs.vscode-extensions.vadimcn; [
          vscode-lldb               # codelldb for Rust/C/C++
        ]);
      };

      # ── Startup plugins (always loaded) ─────────────────────────────────
      # Since we keep lazy.nvim for lazy-loading, all plugins go into
      # startupPlugins so they are on the rtp; lazy.nvim manages actual load timing.
      startupPlugins = {
        core = with pkgs.vimPlugins; [
          # Plugin manager (kept for lazy-loading orchestration)
          lazy-nvim

          # Completion framework
          nvim-cmp
          cmp-nvim-lsp
          cmp-nvim-lsp-signature-help
          cmp-buffer
          cmp-path
          cmp-cmdline
          cmp-git
          cmp_luasnip
          luasnip
          friendly-snippets
          lspkind-nvim

          # LSP
          nvim-lspconfig
          lazydev-nvim
          inc-rename-nvim

          # Treesitter
          (nvim-treesitter.withAllGrammars)
          nvim-treesitter-textobjects

          # UI
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

          # Git
          gitsigns-nvim
          diffview-nvim
          gitlinker-nvim
          vim-signify

          # Editing
          conform-nvim
          nvim-lint
          nvim-ufo
          promise-async
          yanky-nvim
          copilot-vim
          plenary-nvim
          sqlite-lua

          # DAP / Debugging
          nvim-dap
          nvim-dap-python
          nvim-dap-virtual-text
          one-small-step-for-vimkind

          # Language-specific
          rustaceanvim
          go-nvim
          crates-nvim
          venv-selector-nvim

          # Task / Runner
          overseer-nvim
          vim-startuptime

          # Misc
          obsidian-nvim
          aerial-nvim
          avante-nvim
          persistent-breakpoints-nvim
          mason-nvim
        ];

        # Plugins from flake inputs (not in nixpkgs)
        fromInputs = with pkgs.neovimPlugins; [
          auto-indent-nvim
          auto-save-nvim
          bookmarks-nvim
          bufjump-nvim
          cmp-async-path
          cmp-cmdline-history
          cmp-under-comparator
          cmp_yanky
          gp-nvim
          guihua-lua
          leetcode-nvim
          lexima-vim
          local-highlight-nvim
          nvim-dap-view
          nvim-scrollbar
          terminal-nvim
          vimade
          visual-surround-nvim
          bigfile-nvim
          snacks-nvim
          render-markdown-nvim
        ];
      };

      # Not using optionalPlugins since lazy.nvim manages lazy-loading
      optionalPlugins = {};

      # ── Shared libraries ────────────────────────────────────────────────
      sharedLibraries = {
        general = with pkgs; [
          # sqlite-lua may need this
          sqlite
        ];
      };

      # ── Environment variables ───────────────────────────────────────────
      environmentVariables = {};

      # ── Extra Lua packages ──────────────────────────────────────────────
      extraLuaPackages = {
        general = [ (lp: with lp; [ lua-curl nvim-nio mimetypes xml2lua ]) ];
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
          debug = true;
          core = true;
          fromInputs = true;
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
