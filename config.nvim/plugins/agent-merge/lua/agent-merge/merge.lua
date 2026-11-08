-- agent-merge.merge — 3-way merge of line lists via `git merge-file`.
--
-- git merge-file diffs base->mine and base->theirs and combines them: cleanly
-- when the two edits don't overlap, otherwise emitting standard conflict
-- markers. It is always available wherever git is, and needs no repository.

local M = {}

-- Conflict-marker labels: <<<<<<< labels[1] / ======= / >>>>>>> labels[3].
M.labels = { "LOCAL (yours)", "BASE", "REMOTE (agent)" }

local function tmp(lines)
  local f = vim.fn.tempname()
  vim.fn.writefile(lines or {}, f)
  return f
end

--- @param mine string[]    your version (buffer)
--- @param base string[]    common ancestor
--- @param theirs string[]  agent's version (disk)
--- @return string[] merged     merged lines (with conflict markers on conflict)
--- @return integer conflicts   0 = clean, >0 = conflict count, -1 = error
function M.three_way(mine, base, theirs)
  local fm, fb, ft = tmp(mine), tmp(base), tmp(theirs)
  local ok, res = pcall(function()
    return vim.system({
      "git", "merge-file", "-p",
      "-L", M.labels[1], "-L", M.labels[2], "-L", M.labels[3],
      fm, fb, ft,
    }, { text = true }):wait()
  end)
  vim.fn.delete(fm)
  vim.fn.delete(fb)
  vim.fn.delete(ft)
  if not ok then return {}, -1 end -- git unavailable

  local merged = vim.split(res.stdout or "", "\n", { plain = true })
  -- writefile-style output ends in a newline -> drop the trailing empty line.
  if #merged > 0 and merged[#merged] == "" then
    table.remove(merged)
  end
  -- Exit status = number of conflicts, capped at 127; errors exit with 255
  -- (git returns -1), so anything above 127 is an engine error.
  local code = res.code
  if code == nil or code < 0 or code > 127 then return merged, -1 end
  return merged, code
end

return M
