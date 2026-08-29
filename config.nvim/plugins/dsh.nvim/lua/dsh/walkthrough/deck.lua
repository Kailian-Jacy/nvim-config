-- Deck loading and validation.
--
-- A deck is plain data (usually authored as JSON by an agent, then loaded from a
-- file to sidestep --remote-expr quoting). Validation is a first-class feature:
-- authoring mistakes are cheap to make and expensive to spot by eye, so
-- `validate` reports them without touching the UI.
local Config = require("dsh.walkthrough.config")
local Text = require("dsh.walkthrough.text")

local M = {}

local function isnum(v) return type(v) == "number" end
local function isstr(v) return type(v) == "string" and v ~= "" end

--- Resolve a literal `pat` to a 1-based line number in `lines`, preferring the
--- window [lo, hi] and falling back to the whole file. Content-anchored rather
--- than line-numbered, so a deck survives edits to the file it points at.
function M.resolve(lines, pat, lo, hi)
  local last = #lines
  local function scan(a, b)
    a, b = math.max(1, a or 1), math.min(b or last, last)
    for i = a, b do
      if lines[i] and lines[i]:find(pat, 1, true) then return i end
    end
  end
  return scan(lo, hi) or scan(1, last)
end

local file_cache = {}

function M.read(path)
  if file_cache[path] then return file_cache[path] end
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  file_cache[path] = lines
  return lines
end

function M.clear_cache() file_cache = {} end

--- Parse a JSON deck file. Returns deck, err.
function M.parse(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil, "deck file not readable: " .. path
  end
  local raw = table.concat(vim.fn.readfile(path), "\n")
  local ok, deck = pcall(vim.json.decode, raw)
  if not ok then return nil, "invalid JSON: " .. tostring(deck) end
  if type(deck) ~= "table" then return nil, "deck must be a JSON object" end
  if type(deck.steps) ~= "table" or #deck.steps == 0 then
    return nil, "deck.steps must be a non-empty array"
  end
  return deck, nil
end

--- Normalise a parsed deck in place: fill defaults, coerce ranges.
function M.normalise(deck)
  deck.title = deck.title or "walkthrough"
  for i, st in ipairs(deck.steps) do
    st.index = i
    st.ann = st.ann or {}
    st.detail = st.detail or {}
    st.lnum = st.lnum or (st.range and st.range[1]) or 1
    if not st.range then st.range = { st.lnum, st.lnum } end
    st.brief = st.brief or st.title
    st.body = st.body or st.brief
  end
  return deck
end

--- Validate a deck. Returns a list of problem strings (empty == clean).
--- `strict` also reports soft advice (missing sections, long prose).
function M.validate(deck, opts)
  opts = opts or {}
  local o = Config.options
  local maxcode = Config.max_code_width(o)
  local problems = {}
  local function bad(fmt, ...) problems[#problems + 1] = string.format(fmt, ...) end

  local seen_files = {}
  for i, st in ipairs(deck.steps) do
    local tag = ("step %d (%s)"):format(i, st.title or "<untitled>")
    if not isstr(st.title) then bad("%s: missing title", tag) end
    if not isstr(st.file) then
      bad("%s: missing file", tag)
    else
      local lines = M.read(st.file)
      if not lines then
        bad("%s: file not readable: %s", tag, st.file)
      else
        seen_files[st.file] = true
        local n = #lines
        if not isnum(st.lnum) or st.lnum < 1 or st.lnum > n then
          bad("%s: lnum %s outside 1..%d", tag, tostring(st.lnum), n)
        end
        if st.range[2] > n then
          bad("%s: range end %d beyond file length %d", tag, st.range[2], n)
        end
        if st.range[1] > st.range[2] then
          bad("%s: range is inverted (%d..%d)", tag, st.range[1], st.range[2])
        end
        for _, a in ipairs(st.ann) do
          if not isstr(a.pat) then
            bad("%s: annotation with empty pat", tag)
          elseif a.kind ~= "eol" and a.kind ~= "note" then
            bad("%s: annotation kind must be eol|note, got %s", tag, tostring(a.kind))
          else
            local l = M.resolve(lines, a.pat, st.range[1], st.range[2])
            if not l then
              bad("%s: UNRESOLVED anchor %q", tag, a.pat)
            elseif l < st.range[1] or l > st.range[2] then
              bad("%s: anchor %q resolves to line %d, outside range %d..%d",
                tag, a.pat, l, st.range[1], st.range[2])
            end
          end
        end
      end
    end

    for j, blk in ipairs(st.detail) do
      if not isstr(blk.h) then bad("%s: detail[%d] has no heading `h`", tag, j) end
      if not isstr(blk.t) and not isstr(blk.c) then
        bad("%s: detail[%d] has neither prose `t` nor code `c`", tag, j)
      end
      if isstr(blk.t) and isstr(blk.c) then
        bad("%s: detail[%d] sets both `t` and `c`; use two sections", tag, j)
      end
      if isstr(blk.c) then
        for _, l in ipairs(Text.code_lines(blk.c)) do
          local w = vim.fn.strdisplaywidth(l)
          if w > maxcode then
            bad("%s: detail[%d] code line %d cols > %d max -- would truncate:\n    %s",
              tag, j, w, maxcode, l)
          end
        end
      end
    end

    if opts.strict then
      if #st.detail < 3 then
        bad("%s: only %d detail sections (aim for 3-5)", tag, #st.detail)
      end
      local has_code = false
      for _, blk in ipairs(st.detail) do if isstr(blk.c) then has_code = true end end
      if not has_code then bad("%s: no code section -- illustrate it", tag) end
      if isstr(st.brief) and vim.fn.strdisplaywidth(st.brief) > 52 then
        bad("%s: brief is %d cols; keep it to one panel line (<=52)",
          tag, vim.fn.strdisplaywidth(st.brief))
      end
    end
  end
  return problems
end

--- Human-readable validation report.
function M.report(deck, opts)
  local problems = M.validate(deck, opts)
  local nsec, ncode, nann = 0, 0, 0
  for _, st in ipairs(deck.steps) do
    nann = nann + #st.ann
    for _, b in ipairs(st.detail) do
      nsec = nsec + 1
      if b.c then ncode = ncode + 1 end
    end
  end
  local head = ("deck %q: %d steps, %d sections, %d code blocks, %d annotations"):format(
    deck.title, #deck.steps, nsec, ncode, nann)
  if #problems == 0 then
    return head .. "\nvalidation: OK (max code width " .. Config.max_code_width() .. ")"
  end
  return head .. ("\nvalidation: %d problem(s)\n  - "):format(#problems)
    .. table.concat(problems, "\n  - ")
end

return M
