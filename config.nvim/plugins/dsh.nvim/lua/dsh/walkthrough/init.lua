-- dsh.walkthrough — a guided, annotated code walkthrough driven over the RPC
-- socket by an agent, or by keys by the human reading it.
--
-- Every public function is safe to call through:
--   nvim --server "$SOCK" --remote-expr 'luaeval("require(\"dsh.walkthrough\").next()")'
-- and returns a short human-readable string, so the agent can read the result
-- without JSON escaping. Decks are passed as a FILE PATH, never inline, because
-- --remote-expr quoting of large payloads is a reliable source of breakage.
local Annotate = require("dsh.walkthrough.annotate")
local Config = require("dsh.walkthrough.config")
local Deck = require("dsh.walkthrough.deck")
local Hl = require("dsh.walkthrough.hl")
local Panel = require("dsh.walkthrough.panel")

local M = {}

---@type table|nil
M.session = nil
M.deck_path = nil

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function alive(s)
  return s and s.panel_win and vim.api.nvim_win_is_valid(s.panel_win)
end

--- Exempt a window from vimade-style inactive-window fading.
--- vimade reads `vim.w[winid].vimade_disabled == 1` and skips both its
--- nc_windows and nc_buffers paths. Window-scoped on purpose: a buffer variable
--- would follow the annotated source files into the user's other windows.
local function no_dim(win, buf)
  if not Config.options.no_dim then return end
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(function() vim.w[win].vimade_disabled = 1 end)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(function() vim.b[buf].vimade_disabled = 1 end)
  end
end

local function redraw_dimmer()
  local ok, vimade = pcall(require, "vimade")
  if ok and type(vimade.redraw) == "function" then pcall(vimade.redraw) end
end

--- Lock an annotated source buffer against accidental edits, remembering the
--- previous 'modifiable' so close() can restore it. See config.readonly_source
--- for why this is a safety property and not a nicety.
local function lock_source(s, buf)
  if not Config.options.readonly_source then return end
  if s.locked[buf] ~= nil then return end
  if vim.bo[buf].buftype ~= "" then return end
  s.locked[buf] = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = false
end

local function unlock_sources(s)
  for buf, prev in pairs(s.locked or {}) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(function() vim.bo[buf].modifiable = prev end)
    end
  end
  s.locked = {}
end

---------------------------------------------------------------------------
-- keymaps (overridden while active, restored on close)
---------------------------------------------------------------------------
local MODES = { "n", "v", "x" }

local function install_keys(s)
  local o = Config.options
  s.saved_maps, s.lhs = {}, {}
  local function override(lhs, fn, desc)
    if not lhs or lhs == "" then return end
    local resolved = vim.keycode and vim.keycode(lhs)
      or vim.api.nvim_replace_termcodes(lhs, true, true, true)
    s.lhs[#s.lhs + 1] = resolved
    for _, mode in ipairs(MODES) do
      local old = vim.fn.maparg(resolved, mode, false, true)
      if old and not vim.tbl_isempty(old) then
        s.saved_maps[#s.saved_maps + 1] = old
      end
      vim.keymap.set(mode, lhs, fn, { silent = true, desc = desc })
    end
  end
  override(o.keys.next, function() M.next() end, "walkthrough: next step")
  override(o.keys.prev, function() M.prev() end, "walkthrough: prev step")
  override(o.keys.toggle_panel, function() M.toggle_panel() end, "walkthrough: toggle panel")
  override(o.keys.layer, function() M.layer() end, "walkthrough: cycle layer")
end

local function restore_keys(s)
  for _, lhs in ipairs(s.lhs or {}) do
    for _, mode in ipairs(MODES) do pcall(vim.keymap.del, mode, lhs) end
  end
  for _, old in ipairs(s.saved_maps or {}) do pcall(vim.fn.mapset, old) end
  s.saved_maps, s.lhs = {}, {}
end

---------------------------------------------------------------------------
-- windows
---------------------------------------------------------------------------
local function open_panel(s)
  local o = Config.options
  Hl.setup()

  if o.own_tab then
    vim.cmd("tabnew")
    if s.deck.root and vim.fn.isdirectory(s.deck.root) == 1 then
      vim.cmd("tcd " .. vim.fn.fnameescape(s.deck.root))
    end
  end
  s.code_win = vim.api.nvim_get_current_win()

  vim.cmd("topleft " .. o.panel_width .. "vsplit")
  s.panel_win = vim.api.nvim_get_current_win()
  s.tab = vim.api.nvim_get_current_tabpage()
  s.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(s.panel_win, s.panel_buf)

  vim.bo[s.panel_buf].buftype = "nofile"
  vim.bo[s.panel_buf].bufhidden = "wipe"
  vim.bo[s.panel_buf].filetype = "dshwalkthrough"
  pcall(vim.api.nvim_buf_set_name, s.panel_buf, "walkthrough://" .. s.deck.title)

  local w = s.panel_win
  vim.wo[w].number = false
  vim.wo[w].relativenumber = false
  vim.wo[w].wrap = false
  vim.wo[w].signcolumn = "no"
  vim.wo[w].foldcolumn = "0"
  vim.wo[w].cursorline = false
  vim.wo[w].winfixwidth = true
  pcall(function() vim.wo[w].winfixbuf = true end)
  pcall(function() vim.wo[w].statuscolumn = "" end)
  no_dim(s.panel_win, s.panel_buf)

  local kopts = { buffer = s.panel_buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    local l = vim.api.nvim_win_get_cursor(s.panel_win)[1]
    for i = l, 1, -1 do
      if s.step_of_line[i] then return M.goto_step(s.step_of_line[i]) end
    end
  end, kopts)
  vim.keymap.set("n", "<Tab>", function() M.layer() end, kopts)
  vim.keymap.set("n", "q", function() M.toggle_panel() end, kopts)

  vim.api.nvim_set_current_win(s.code_win)
end

local function ensure_code_win(s)
  if s.code_win and vim.api.nvim_win_is_valid(s.code_win) and s.code_win ~= s.panel_win then
    no_dim(s.code_win, nil)
    return s.code_win
  end
  local tab = (s.tab and vim.api.nvim_tabpage_is_valid(s.tab)) and s.tab or 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if w ~= s.panel_win and vim.api.nvim_win_get_config(w).relative == "" then
      s.code_win = w
      no_dim(w, nil)
      return w
    end
  end
  local prev = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(s.panel_win)
  vim.cmd("rightbelow vsplit")
  s.code_win = vim.api.nvim_get_current_win()
  no_dim(s.code_win, nil)
  pcall(vim.api.nvim_set_current_win, prev)
  return s.code_win
end

---------------------------------------------------------------------------
-- public API
---------------------------------------------------------------------------
function M.setup(opts)
  Config.setup(opts)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("DshWalkthroughHl", { clear = true }),
    callback = function() if M.session then Hl.setup() end end,
  })
  return "dsh.walkthrough configured (panel_width="
    .. Config.options.panel_width
    .. ", max_code_width=" .. Config.max_code_width() .. ")"
end

--- Validate a deck file without touching the UI.
--- @param path string
--- @param strict boolean|nil also report soft authoring advice
function M.validate(path, strict)
  Deck.clear_cache()
  local deck, err = Deck.parse(path)
  if not deck then return "ERROR: " .. err end
  Deck.normalise(deck)
  return Deck.report(deck, { strict = strict ~= false })
end

--- Load a deck file and open the walkthrough. Refuses to open a deck with
--- structural problems, so the agent sees the report instead of a broken panel.
--- @param path string
--- @param opts table|nil { force = true } to open despite problems
function M.open(path, opts)
  opts = opts or {}
  Deck.clear_cache()
  local deck, err = Deck.parse(path)
  if not deck then return "ERROR: " .. err end
  Deck.normalise(deck)

  local problems = Deck.validate(deck, { strict = false })
  if #problems > 0 and not opts.force then
    return "REFUSED: deck has " .. #problems .. " problem(s); fix or pass force=true\n  - "
      .. table.concat(problems, "\n  - ")
  end

  M.close()
  M.deck_path = path
  local s = {
    deck = deck, idx = 1, layer = 1,
    unresolved = {}, step_of_line = {}, line_of_step = {}, locked = {},
  }
  M.session = s
  open_panel(s)
  M.goto_step(1)
  redraw_dimmer()
  return M.status() .. (#problems > 0 and ("\nWARNING: opened with " .. #problems .. " problem(s)") or "")
end

--- Re-read the current deck file and reopen at the same step.
function M.reload()
  if not M.deck_path then return "ERROR: no deck loaded" end
  local idx = M.session and M.session.idx or 1
  local layer = M.session and M.session.layer or 1
  local res = M.open(M.deck_path)
  if M.session then
    M.session.layer = layer
    M.goto_step(idx)
  end
  return res
end

function M.close()
  local s = M.session
  if not s then return "no active walkthrough" end
  -- hand windows back to the dimmer before tearing down
  if s.code_win and vim.api.nvim_win_is_valid(s.code_win) then
    pcall(function() vim.w[s.code_win].vimade_disabled = nil end)
  end
  for _, st in ipairs(s.deck.steps) do
    local b = vim.fn.bufnr(st.file)
    if b > 0 then Annotate.clear(b) end
  end
  restore_keys(s)
  unlock_sources(s)
  if alive(s) then
    local w = s.panel_win
    s.panel_win = nil
    pcall(vim.api.nvim_win_close, w, true)
  end
  M.session = nil
  redraw_dimmer()
  return "walkthrough closed; annotations cleared and keymaps restored"
end

function M.toggle_panel()
  local s = M.session
  if not s then return "ERROR: no active walkthrough" end
  if alive(s) then
    local w = s.panel_win
    s.panel_win = nil
    pcall(vim.api.nvim_win_close, w, true)
    return "panel hidden"
  end
  open_panel(s)
  install_keys(s)
  M.goto_step(s.idx)
  return "panel shown"
end

--- Jump to step `i` (1-based, clamped).
function M.goto_step(i)
  local s = M.session
  if not s then return "ERROR: no active walkthrough" end
  if not alive(s) then open_panel(s) end
  if not s.lhs then install_keys(s) end

  local steps = s.deck.steps
  i = math.max(1, math.min(#steps, tonumber(i) or 1))
  local prev = steps[s.idx]
  s.idx = i
  local st = steps[i]
  local cw = ensure_code_win(s)

  if prev and prev.file ~= st.file then
    local pb = vim.fn.bufnr(prev.file)
    if pb > 0 then Annotate.clear(pb) end
  end

  local buf = vim.fn.bufadd(st.file)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true
  lock_source(s, buf)
  if vim.api.nvim_win_get_buf(cw) ~= buf then
    vim.api.nvim_win_set_buf(cw, buf)
  end
  if Config.options.signs then vim.wo[cw].signcolumn = "yes:1" end

  s.unresolved = Annotate.apply(buf, st, cw)

  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(cw, { math.min(st.lnum, last), 0 })
  vim.api.nvim_win_call(cw, function()
    if vim.wo.foldenable then pcall(vim.cmd, "normal! zv") end
    vim.cmd("normal! zz")
  end)

  s.line_of_step, s.step_of_line = Panel.render(s)

  -- No nvim_echo by default: with a notification UI it surfaces as a popup on
  -- every jump. Position lives in the panel header instead.
  if Config.options.echo then
    vim.api.nvim_echo({ { ("[%d/%d] "):format(i, #steps), "Comment" },
      { st.title, "Function" } }, false, {})
  end
  return M.status()
end

local function step_relative(delta)
  local s = M.session
  if not s then return "ERROR: no active walkthrough" end
  -- the walkthrough owns one tab; hop back to it rather than hijacking the tab
  -- the user is currently working in
  if s.tab and vim.api.nvim_tabpage_is_valid(s.tab)
    and vim.api.nvim_get_current_tabpage() ~= s.tab then
    vim.api.nvim_set_current_tabpage(s.tab)
  end
  if not alive(s) then open_panel(s) end
  return M.goto_step(s.idx + delta)
end

function M.next() return step_relative(1) end
function M.prev() return step_relative(-1) end

--- Cycle, or set, the disclosure layer.
function M.layer(to)
  local s = M.session
  if not s then return "ERROR: no active walkthrough" end
  local n = #Config.options.layers
  s.layer = tonumber(to) or (s.layer % n) + 1
  s.layer = math.max(1, math.min(n, s.layer))
  if not alive(s) then open_panel(s) end
  s.line_of_step, s.step_of_line = Panel.render(s)
  return M.status()
end

--- One-line state summary, for the agent to read after any call.
function M.status()
  local s = M.session
  if not s then return "walkthrough: inactive" end
  local st = s.deck.steps[s.idx]
  return ("walkthrough %q | step %d/%d %q | %s:%d | layer %s%s"):format(
    s.deck.title, s.idx, #s.deck.steps, st.title,
    vim.fn.fnamemodify(st.file, ":t"), st.lnum,
    Config.options.layers[s.layer] or "?",
    #s.unresolved > 0 and (" | UNRESOLVED: " .. table.concat(s.unresolved, ", ")) or "")
end

--- Full machine-readable state, for when the agent needs structure.
function M.state()
  local s = M.session
  if not s then return vim.json.encode({ active = false }) end
  local titles = {}
  for i, st in ipairs(s.deck.steps) do titles[i] = st.title end
  return vim.json.encode({
    active = true,
    title = s.deck.title,
    idx = s.idx,
    total = #s.deck.steps,
    layer = Config.options.layers[s.layer],
    layers = Config.options.layers,
    step = {
      title = s.deck.steps[s.idx].title,
      file = s.deck.steps[s.idx].file,
      lnum = s.deck.steps[s.idx].lnum,
      sections = #s.deck.steps[s.idx].detail,
      annotations = #s.deck.steps[s.idx].ann,
    },
    unresolved = s.unresolved,
    titles = titles,
    panel_width = Config.options.panel_width,
    max_code_width = Config.max_code_width(),
    tab = s.tab and vim.api.nvim_tabpage_get_number(s.tab) or nil,
  })
end

--- Authoring limits, so an agent can ask instead of guessing.
function M.limits()
  return vim.json.encode({
    panel_width = Config.options.panel_width,
    max_code_width = Config.max_code_width(),
    max_prose_width = Config.max_prose_width(),
    layers = Config.options.layers,
    annotation_kinds = { "eol", "note" },
  })
end

return M
