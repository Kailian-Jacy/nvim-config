-- nixCats utilities: provides nixCats() function for category queries
-- In non-Nix environments, nixCatsUtils.setup provides a fallback
local ok, nixCatsUtils = pcall(require, "nixCatsUtils")
if ok then
  nixCatsUtils.setup({
    non_nix_value = true, -- In non-Nix env, nixCats("category") returns true
  })
end

local is_nix = vim.g.nixCats ~= nil

if is_nix then
  -- ── Nix environment (nixCats) ──────────────────────────────────────────
  --
  -- How it works:
  --   1. nixCats places ALL startupPlugins on &rtp before init.lua runs.
  --   2. lazy.nvim is itself a startupPlugin, so require("lazy") succeeds.
  --   3. lazy.setup({ spec = { import = "plugins" } }) scans lua/plugins/*.lua,
  --      discovers each plugin spec, and matches them to already-loaded rtp
  --      entries (by plugin name). Because install.missing=false it won't try
  --      to clone anything.
  --   4. lazy.nvim still calls each spec's `config` function, honours `event`,
  --      `ft`, `cmd`, `keys` triggers, and processes `dependencies`.
  --   5. `reset_packpath = false` and `rtp.reset = false` prevent lazy.nvim
  --      from clobbering the paths nixCats set up.
  --
  -- Known considerations (see PR description for full details):
  --   - Plugins may appear "not installed" in :Lazy UI (cosmetic only).
  --   - Load order is: nixCats rtp order first, then lazy.nvim's scheduling.
  --     In practice this works because lazy.nvim defers to rtp for already-
  --     loaded plugins and only intervenes for lazy-loaded ones.
  --   - after/plugin/ scripts run via normal Vim rtp mechanics, unaffected.

  if not pcall(require, "lazy") then
    vim.notify("[nixCats] lazy.nvim not found on rtp — check flake.nix startupPlugins", vim.log.levels.ERROR)
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
    install = { missing = false },   -- Nix provides everything; never git-clone
    checker = { enabled = false },   -- No update checks
    change_detection = { enabled = false },
    performance = {
      reset_packpath = false,        -- Keep nixCats-managed packpath intact
      rtp = {
        reset = false,               -- Keep nixCats-managed rtp intact
        disabled_plugins = {
          "gzip",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
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
