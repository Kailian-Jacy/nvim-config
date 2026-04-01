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
  -- nixCats already puts all startupPlugins on the runtimepath.
  -- lazy.nvim is used only as an event scheduler / lazy-loader.
  -- It does NOT manage plugin paths or installation.

  -- lazy.nvim itself is provided by nixCats as a startupPlugin (on rtp)
  if not pcall(require, "lazy") then
    vim.notify("[nixCats] lazy.nvim not available in Nix environment", vim.log.levels.WARN)
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
    performance = {
      reset_packpath = false, -- Don't reset nixCats-managed packpath
      rtp = {
        reset = false, -- Don't reset nixCats-managed rtp
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
