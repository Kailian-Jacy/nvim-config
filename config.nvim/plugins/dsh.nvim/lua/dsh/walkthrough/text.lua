-- Text measuring, wrapping and a minimal code tokenizer.
local M = {}

local function fill(para, width, indent, hang)
  local out, line = {}, ""
  for word in para:gmatch("%S+") do
    local pre = (#out == 0) and indent or hang
    if line == "" then
      line = pre .. word
    elseif vim.fn.strdisplaywidth(line .. " " .. word) <= width then
      line = line .. " " .. word
    else
      out[#out + 1] = line
      line = hang .. word
    end
  end
  if line ~= "" then out[#out + 1] = line end
  return out
end

--- Wrap prose to `width`, preserving blank lines, hanging-indenting list items
--- and leaving pre-indented (aligned) lines verbatim when they already fit.
function M.wrap(text, width)
  local out = {}
  for _, para in ipairs(vim.split(text or "", "\n", { plain = true })) do
    if para:match("^%s*$") then
      out[#out + 1] = ""
    else
      local lead = para:match("^(%s*[•%-]%s+)") or para:match("^(%s*%d+%.%s+)")
      if lead then
        vim.list_extend(out, fill(para:sub(#lead + 1), width, lead, string.rep(" ", #lead)))
      elseif para:match("^%s") then
        if vim.fn.strdisplaywidth(para) <= width then
          out[#out + 1] = para
        else
          vim.list_extend(out, fill(para, width, "", para:match("^(%s*)") .. "  "))
        end
      else
        vim.list_extend(out, fill(para, width, "", ""))
      end
    end
  end
  return out
end

--- Split a code block into lines, dropping blank leading/trailing rows so a
--- card never opens or closes on an empty coloured band.
function M.code_lines(text)
  local ls = vim.split(((text or ""):gsub("^\n", "")), "\n", { plain = true })
  while #ls > 0 and ls[1]:match("^%s*$") do table.remove(ls, 1) end
  while #ls > 0 and ls[#ls]:match("^%s*$") do table.remove(ls) end
  return ls
end

local KEYWORDS = {}
for w in ([[if then else elseif end for in do while repeat until return local
function and or not nil true false break]]):gmatch("%S+") do
  KEYWORDS[w] = true
end

--- Tokenize one pseudo-code line into byte ranges { start0, end0, hl_group }.
--- Comments (and `-->` annotation arrows) consume the rest of the line, so a
--- keyword inside a comment is not separately coloured.
function M.tokens(text)
  local toks, i, n = {}, 1, #text
  while i <= n do
    local c = text:sub(i, i)
    if text:find("^%-%-", i) then
      toks[#toks + 1] = { i - 1, n, "DshWalkCodeCom" }
      break
    elseif c == '"' then
      local j = text:find('"', i + 1, true) or n
      toks[#toks + 1] = { i - 1, j, "DshWalkCodeStr" }
      i = j + 1
    elseif c:match("[%a_]") then
      local a, b = text:find("^[%w_]+", i)
      if KEYWORDS[text:sub(a, b)] then
        toks[#toks + 1] = { a - 1, b, "DshWalkCodeKw" }
      end
      i = b + 1
    elseif c:match("%d") then
      local a, b = text:find("^%d+", i)
      toks[#toks + 1] = { a - 1, b, "DshWalkCodeNum" }
      i = b + 1
    else
      i = i + 1
    end
  end
  return toks
end

return M
