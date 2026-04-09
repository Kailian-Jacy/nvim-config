-- treesitter-compat.lua — Compatibility shim for Neovim 0.12+ / nvim-treesitter main branch
--
-- Background:
--   Neovim 0.12 ships with nvim-treesitter's "main" branch, which removed many
--   legacy submodules (nvim-treesitter.configs, nvim-treesitter.parsers,
--   nvim-treesitter.ts_utils, nvim-treesitter.indent, nvim-treesitter.highlight,
--   nvim-treesitter.locals).  Third-party plugins that `require()` these modules
--   will crash at startup.
--
-- Strategy:
--   Inject minimal no-op / thin-wrapper shims via `package.preload` *before*
--   lazy.nvim loads any plugin.  Plugins that already pcall-guard their requires
--   are unaffected.  Plugins that hard-require the old API will get a safe stub
--   instead of a crash.
--
-- The shims intentionally do the least possible work.  They are NOT full
-- reimplementations — they exist only to prevent errors.  Feature-level compat
-- is left to each plugin's upstream maintainer.
--
-- See: https://github.com/Kailian-Jacy/nvim-config/issues/51

local M = {}

-- Track which shims are installed (for diagnostics)
-- Initialise before the version gate so M._installed is never nil.
M._installed = {}

-- Only install shims on Neovim 0.12+ where the modules were removed
local version = vim.version()
if version.major == 0 and version.minor < 12 then
  return M
end

local function install(mod_name, factory)
  if package.preload[mod_name] then
    return -- already provided by something else
  end
  package.preload[mod_name] = factory
  table.insert(M._installed, mod_name)
end

-------------------------------------------------------------------------------
-- nvim-treesitter.configs  (most common — used by go.nvim, many configs)
-------------------------------------------------------------------------------
install("nvim-treesitter.configs", function()
  return {
    setup = function(_opts) end,               -- no-op
    get_module = function(_mod) return {} end,  -- return empty module
    commands = {},
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.parsers
-------------------------------------------------------------------------------
install("nvim-treesitter.parsers", function()
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
install("nvim-treesitter.ts_utils", function()
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
install("nvim-treesitter.locals", function()
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
-------------------------------------------------------------------------------
install("nvim-treesitter.indent", function()
  return {
    get_indent = function(_lnum) return -1 end,
    attach = function(_bufnr) end,
    detach = function(_bufnr) end,
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.highlight
-------------------------------------------------------------------------------
install("nvim-treesitter.highlight", function()
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
install("nvim-treesitter.textobjects", function()
  return {
    select = { select_textobject = function() end },
    move = {},
    swap = {},
  }
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.query  (used by go.nvim ts/nodes.lua → iter_prepared_matches)
-------------------------------------------------------------------------------
install("nvim-treesitter.query", function()
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
-------------------------------------------------------------------------------
install("nvim-treesitter.utils", function()
  return setmetatable({}, {
    __index = function(_, _key)
      return function() end
    end,
  })
end)

-------------------------------------------------------------------------------
-- nvim-treesitter.info  (used by go.nvim health.lua → installed_parsers())
-------------------------------------------------------------------------------
install("nvim-treesitter.info", function()
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
    vim.notify(
      string.format(
        "[treesitter-compat] Installed %d shim(s): %s",
        #M._installed,
        table.concat(M._installed, ", ")
      ),
      vim.log.levels.DEBUG
    )
  end
end)

return M
