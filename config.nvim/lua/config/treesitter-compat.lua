-- treesitter-compat.lua — Compatibility shim for Neovim 0.12+ / nvim-treesitter main branch
--
-- Background:
--   Neovim 0.12 ships with nvim-treesitter's "main" branch, which removed many
--   legacy submodules (nvim-treesitter.configs, nvim-treesitter.ts_utils,
--   nvim-treesitter.highlight, nvim-treesitter.locals, etc.).  Third-party
--   plugins that `require()` these modules will crash at startup.
--
-- Strategy:
--   Inject minimal no-op / thin-wrapper shims via `package.preload` *before*
--   lazy.nvim loads any plugin.  Each shim uses a "deferred preloader" that
--   re-checks at require-time whether the real module has become available
--   (e.g., after lazy.nvim adds plugin directories to package.path).  If the
--   real module exists, it is loaded instead of the shim.  This ensures we
--   NEVER shadow modules that nvim-treesitter still ships (parsers, indent,
--   config, install, etc.).
--
-- The shims intentionally do the least possible work.  They are NOT full
-- reimplementations — they exist only to prevent errors.  Feature-level compat
-- is left to each plugin's upstream maintainer.
--
-- See: https://github.com/Kailian-Jacy/nvim-config/issues/51

local M = {}

-- Track which shims are installed (for diagnostics)
-- Initialise before the version gate so these are never nil.
M._installed = {}  -- modules where a deferred preloader was registered
M._deferred = {}   -- modules where the real module was loaded (at require-time)
M._shimmed = {}    -- modules where the shim was actually used (at require-time)

-- Only install shims on Neovim 0.12+ where the modules were removed
local version = vim.version()
if version.major == 0 and version.minor < 12 then
  return M
end

--- Register a deferred preloader for `mod_name`.
---
--- At registration time, if the real module file already exists on
--- `package.path`, the shim is skipped entirely.  Otherwise a "deferred
--- preloader" is installed in `package.preload`.  When the module is
--- actually `require()`-d (potentially after lazy.nvim has extended
--- `package.path`), the preloader re-checks for the real module file and
--- loads it if found; only as a last resort does it fall back to the shim.
---
--- This prevents us from ever shadowing modules that nvim-treesitter's
--- main branch still ships (e.g., parsers.lua, indent.lua, config.lua).
---
---@param mod_name string   The module name (e.g. "nvim-treesitter.parsers")
---@param shim_fn  function Factory that returns the shim table
---@return boolean          true if a preloader was installed
function M.safe_preload(mod_name, shim_fn)
  -- If real module already exists on the current package.path, skip
  if package.searchpath(mod_name, package.path) then
    return false
  end
  -- If something else already registered a preloader, don't override
  if package.preload[mod_name] then
    return false
  end
  -- Install a deferred preloader.
  -- At require-time, package.path may have been extended by the plugin
  -- manager (lazy.nvim adds plugin dirs after our init code runs).
  -- The preloader removes itself, re-checks for the real module, and
  -- only falls back to the shim when nothing else can provide the module.
  package.preload[mod_name] = function()
    -- Remove ourselves so the normal file searchers can run unimpeded
    package.preload[mod_name] = nil
    -- Re-check: the real module may now be reachable
    local real_path = package.searchpath(mod_name, package.path)
    if real_path then
      local loader = loadfile(real_path)
      if loader then
        table.insert(M._deferred, mod_name)
        return loader(mod_name, real_path)
      end
    end
    -- No real module found — use our shim
    table.insert(M._shimmed, mod_name)
    return shim_fn()
  end
  table.insert(M._installed, mod_name)
  return true
end

-------------------------------------------------------------------------------
-- nvim-treesitter.configs  (most common — used by go.nvim, many configs)
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.configs", function()
  return {
    setup = function(_opts) end,               -- no-op
    get_module = function(_mod) return {} end,  -- return empty module
    commands = {},
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.parsers
--
-- NOTE: In nvim-treesitter main branch, parsers.lua (75 kB) still exists and
-- contains the full parser registry.  The deferred preloader will detect this
-- and load the real module instead of the shim below.  The shim only activates
-- if, for some reason, the real module is not found at require-time.
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.parsers", function()
  local parsers_mod = {}

  -- has_parser(lang) — check via built-in API
  function parsers_mod.has_parser(lang)
    lang = lang or vim.treesitter.language.get_lang(vim.bo.filetype)
    if not lang then return false end
    return pcall(vim.treesitter.language.inspect, lang)
  end

  -- get_parser_configs() — return empty table (plugins only use it for iteration)
  function parsers_mod.get_parser_configs()
    return {}
  end

  -- get_buf_lang(bufnr) — derive language from filetype
  function parsers_mod.get_buf_lang(bufnr)
    bufnr = bufnr or 0
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    return vim.treesitter.language.get_lang(ft) or ft
  end

  -- ft_to_lang(ft) — map filetype to treesitter language
  function parsers_mod.ft_to_lang(ft)
    return vim.treesitter.language.get_lang(ft) or ft
  end

  -- list — empty metatable that returns {} for any key (parser list stub)
  parsers_mod.list = setmetatable({}, {
    __index = function() return {} end,
  })

  return parsers_mod
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.ts_utils
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.ts_utils", function()
  local ts_utils = {}

  function ts_utils.get_node_at_cursor(winnr)
    winnr = winnr or 0
    return vim.treesitter.get_node({ bufnr = vim.api.nvim_win_get_buf(winnr) })
  end

  function ts_utils.get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr or 0)
  end

  function ts_utils.get_node_range(node)
    if not node then return 0, 0, 0, 0 end
    return node:range()
  end

  -- Stub for any other function: return nil
  return setmetatable(ts_utils, {
    __index = function(_, _key)
      return function() end
    end,
  })
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.locals
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.locals", function()
  local locals = {}

  function locals.get_definitions(_bufnr) return {} end
  function locals.get_references(_bufnr) return {} end
  function locals.get_scopes(_bufnr) return {} end
  function locals.get_locals(_bufnr) return {} end
  function locals.find_definition(_node, _bufnr) return nil end
  function locals.find_usages(_node, _scope, _bufnr) return {} end

  return setmetatable(locals, {
    __index = function(_, _key)
      return function() return {} end
    end,
  })
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.indent
--
-- NOTE: In nvim-treesitter main branch, indent.lua still exists.  The deferred
-- preloader will detect this and load the real module instead of the shim.
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.indent", function()
  return {
    get_indent = function(_lnum) return -1 end,
    attach = function(_bufnr) end,
    detach = function(_bufnr) end,
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.highlight
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.highlight", function()
  return {
    attach = function(_bufnr, _lang) end,
    detach = function(_bufnr) end,
    set_custom_captures = function(_captures) end,
    on = true,
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.textobjects (old plugin integration module)
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.textobjects", function()
  return {
    select = { select_textobject = function() end },
    move = {},
    swap = {},
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.query  (used by go.nvim ts/nodes.lua → iter_prepared_matches)
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.query", function()
  local query = {}

  --- Stub for the removed iter_prepared_matches.
  --- Returns an empty iterator so `for match in ...` loops simply skip.
  function query.iter_prepared_matches(_parsed_query, _root, _bufnr, _start_row, _end_row)
    return function() return nil end
  end

  --- get_query — forward to vim.treesitter.query.get when available
  function query.get_query(lang, query_name)
    local ok, result = pcall(vim.treesitter.query.get, lang, query_name)
    if ok then return result end
    return nil
  end

  return setmetatable(query, {
    __index = function(_, _key)
      return function() end
    end,
  })
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.utils  (dead import in go.nvim ts/go.lua — needs empty stub)
-- NOTE: The real module is nvim-treesitter.util (singular).  This shim is for
-- the *plural* name that go.nvim references, which does not exist in any
-- version of nvim-treesitter.
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.utils", function()
  return setmetatable({}, {
    __index = function(_, _key)
      return function() end
    end,
  })
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.info  (used by go.nvim health.lua → installed_parsers())
-------------------------------------------------------------------------------
M.safe_preload("nvim-treesitter.info", function()
  local info = {}

  --- Return a list of parser languages that Neovim can load.
  --- In 0.12+ parsers ship with Neovim itself; we probe
  --- vim.treesitter.language.inspect to build the list.
  function info.installed_parsers()
    local available = {}
    local candidates = {
      "bash", "c", "cpp", "css", "go", "gomod", "gosum", "gowork",
      "html", "java", "javascript", "json", "lua", "markdown",
      "python", "query", "regex", "rust", "toml", "tsx", "typescript",
      "vim", "vimdoc", "yaml", "zig",
    }
    for _, lang in ipairs(candidates) do
      if pcall(vim.treesitter.language.inspect, lang) then
        table.insert(available, lang)
      end
    end
    return available
  end

  return setmetatable(info, {
    __index = function(_, _key)
      return function() return {} end
    end,
  })
end)

-- Log installed shims at DEBUG level for diagnostics
vim.schedule(function()
  if #M._installed > 0 then
    -- Build a detailed message showing which modules were shimmed vs deferred
    local parts = {}
    if #M._shimmed > 0 then
      table.insert(parts, "shimmed: " .. table.concat(M._shimmed, ", "))
    end
    if #M._deferred > 0 then
      table.insert(parts, "deferred to real: " .. table.concat(M._deferred, ", "))
    end
    local detail = #parts > 0 and " (" .. table.concat(parts, "; ") .. ")" or ""
    vim.notify(
      string.format(
        "[treesitter-compat] Registered %d deferred preloader(s)%s",
        #M._installed,
        detail
      ),
      vim.log.levels.DEBUG
    )
  end
end)

return M
