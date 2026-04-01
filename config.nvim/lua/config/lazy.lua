-- nixCats integration: detect Nix environment
-- When built via nixCats, vim.g.nixCats is set automatically.
-- We use the lazyCat-style approach: lazy.nvim stays as the lazy-loader,
-- but plugins are provided by Nix (dev mode), and install/update is disabled.
local is_nix = vim.g["nixCats-special-rtp-entry-nixCats"] ~= nil

if is_nix then
  -- ── Nix environment (nixCats) ──────────────────────────────────────────
  -- Plugins are already on the runtimepath via nixCats.
  -- lazy.nvim is used only for lazy-loading orchestration, NOT for downloading.

  local nixCats = require("nixCats")
  local myNeovimPackages = nixCats.vimPackDir .. "/pack/myNeovimPackages"

  -- lazy.nvim is provided by Nix as a startupPlugin; find it
  local lazypath = myNeovimPackages .. "/start/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    -- Fallback: maybe it was put in opt
    lazypath = myNeovimPackages .. "/opt/lazy.nvim"
  end
  if not vim.uv.fs_stat(lazypath) then
    vim.notify("[nixCats] lazy.nvim not found in Nix-provided plugins", vim.log.levels.WARN)
    return
  end

  require("lazy").setup({
    spec = {
      { import = "plugins" },
    },
    defaults = {
      lazy = false,
      version = false,
    },
    install = { missing = false }, -- Nix provides everything
    checker = { enabled = false }, -- No update checks
    change_detection = { enabled = false },
    -- Tell lazy.nvim to treat ALL plugins as "dev" (local) dependencies
    dev = {
      path = function(plugin)
        if vim.fn.isdirectory(myNeovimPackages .. "/start/" .. plugin.name) == 1 then
          return myNeovimPackages .. "/start/" .. plugin.name
        elseif vim.fn.isdirectory(myNeovimPackages .. "/opt/" .. plugin.name) == 1 then
          return myNeovimPackages .. "/opt/" .. plugin.name
        end
        -- Fallback for plugins whose Nix pname differs from lazy spec name
        return "~/projects/" .. plugin.name
      end,
      patterns = { "" }, -- Mark ALL plugins as dev so lazy uses Nix paths
      fallback = true, -- Allow lazy to download if not found (safety net)
    },
    performance = {
      rtp = {
        reset = false, -- Don't reset rtp — Nix already set it up
        disabled_plugins = {
          "gzip",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
      reset_packpath = false,
    },
  })
else
  -- ── Non-Nix environment (original setup, unchanged) ────────────────────
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

  if not vim.uv.fs_stat(lazypath) then
    -- bootstrap lazy.nvim
    -- stylua: ignore
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  end
  vim.opt.rtp:prepend(lazypath)

  require("lazy").setup({
    spec = {
      -- import/override with your plugins
      { import = "plugins" },
    },
    defaults = {
      -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
      -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
      lazy = false,
      -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
      -- have outdated releases, which may break your Neovim install.
      version = false, -- always use the latest git commit
    },
    -- install = { colorscheme = { "dracular" } },
    checker = { enabled = true, notify = false }, -- automatically check for plugin updates
    performance = {
      rtp = {
        -- disable some rtp plugins
        disabled_plugins = {
          "gzip",
          -- "matchit",
          -- "matchparen",
          -- "netrwPlugin",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
    },
  })
end
