-- Highlight groups. Derived from the active colorscheme so the walkthrough
-- inherits the user's theme instead of hard-coding colours.
local M = {}

local function get(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }) or {}
end

--- Alpha-blend `top` over `bottom` (both 24-bit ints).
local function blend(top, bottom, alpha)
  if not top or not bottom then return top or bottom end
  local function ch(v, sh) return math.floor(v / sh) % 256 end
  return math.floor(ch(top, 65536) * alpha + ch(bottom, 65536) * (1 - alpha)) * 65536
    + math.floor(ch(top, 256) * alpha + ch(bottom, 256) * (1 - alpha)) * 256
    + math.floor(ch(top, 1) * alpha + ch(bottom, 1) * (1 - alpha))
end

M.blend = blend

--- (Re)define every group. Idempotent; safe to call on ColorScheme.
function M.setup()
  local normal, visual = get("Normal"), get("Visual")
  local ptr = get("DiagnosticWarn").fg or get("WarningMsg").fg
  local note = get("DiagnosticInfo").fg or get("Function").fg
  local rule = get("NonText").fg or get("Comment").fg

  M.tint_bg = visual.bg

  -- ── code-window decoration ───────────────────────────────────────────
  -- region tint on the lines a step is about
  vim.api.nvim_set_hl(0, "DshWalkRegion", { bg = visual.bg })
  vim.api.nvim_set_hl(0, "DshWalkSign", { fg = ptr })
  -- end-of-line pointers
  vim.api.nvim_set_hl(0, "DshWalkPtr", { fg = ptr, italic = true })
  -- virt_lines are their own screen lines, so line_hl_group cannot reach them;
  -- the tinted variants carry the region background themselves.
  vim.api.nvim_set_hl(0, "DshWalkNote", { fg = note, italic = true })
  vim.api.nvim_set_hl(0, "DshWalkRule", { fg = rule })
  vim.api.nvim_set_hl(0, "DshWalkNoteT", { fg = note, bg = visual.bg, italic = true })
  vim.api.nvim_set_hl(0, "DshWalkRuleT", { fg = rule, bg = visual.bg })

  -- ── panel chrome ─────────────────────────────────────────────────────
  vim.api.nvim_set_hl(0, "DshWalkHead", { fg = get("Title").fg, bold = true })
  vim.api.nvim_set_hl(0, "DshWalkAct", { fg = get("Statement").fg, bold = true })
  vim.api.nvim_set_hl(0, "DshWalkCur", { fg = get("Function").fg, bold = true })
  vim.api.nvim_set_hl(0, "DshWalkStar", { fg = get("Special").fg })
  vim.api.nvim_set_hl(0, "DshWalkDim", { fg = get("Comment").fg })
  vim.api.nvim_set_hl(0, "DshWalkSection", {
    fg = get("Keyword").fg or get("Statement").fg, bold = true,
  })
  -- body prose is plain foreground on purpose: it is the text meant to be READ,
  -- so it must not be dimmed like a comment.
  vim.api.nvim_set_hl(0, "DshWalkBody", { fg = normal.fg })
  vim.api.nvim_set_hl(0, "DshWalkBrief", { fg = blend(normal.fg, normal.bg, 0.70) })

  -- ── code card ────────────────────────────────────────────────────────
  -- Prefer the theme's CursorLine, which is designed as a subtle lift from
  -- Normal; only compute a blend when the theme leaves it unset.
  local cbg = get("CursorLine").bg
  if not cbg or cbg == normal.bg then
    cbg = blend(normal.fg, normal.bg, 0.09)
  end
  M.code_bg = cbg
  vim.api.nvim_set_hl(0, "DshWalkCodeBlk", { fg = normal.fg, bg = cbg })
  vim.api.nvim_set_hl(0, "DshWalkCodeKw", { fg = get("Keyword").fg or get("Statement").fg, bg = cbg })
  vim.api.nvim_set_hl(0, "DshWalkCodeStr", { fg = get("String").fg, bg = cbg })
  vim.api.nvim_set_hl(0, "DshWalkCodeNum", { fg = get("Number").fg or get("Constant").fg, bg = cbg })
  vim.api.nvim_set_hl(0, "DshWalkCodeCom", {
    fg = blend(get("Comment").fg, normal.fg, 0.55), bg = cbg, italic = true,
  })
end

return M
