-- tests/test_bigfile_merge.lua
-- Validates the bigfile migration: LunarVim/bigfile.nvim removed,
-- Snacks bigfile configuration enhanced with all necessary features.

local errors = {}
local repo_root = "/tmp/nvim-config-yaml-fix"

local function check(name, ok, detail)
  if ok then
    print("  ✓ " .. name)
  else
    local msg = name .. (detail and (": " .. detail) or "")
    print("  ✗ " .. msg)
    table.insert(errors, msg)
  end
end

print("=== bigfile migration tests ===\n")

-- 1. bigfile.lua is deleted
print("[1] LunarVim/bigfile.nvim plugin file removed")
local bigfile_path = repo_root .. "/config.nvim/lua/plugins/bigfile.lua"
check("bigfile.lua does not exist", vim.fn.filereadable(bigfile_path) == 0)

-- 2. Read miscellaneous.lua source and verify Snacks bigfile config
print("\n[2] Snacks bigfile configuration")
local misc_path = repo_root .. "/config.nvim/lua/plugins/miscellaneous.lua"
local ok, lines = pcall(vim.fn.readfile, misc_path)
assert(ok, "Cannot read miscellaneous.lua")
local src = table.concat(lines, "\n")

check("bigfile.enabled = true present", src:find("bigfile%s*=%s*{") ~= nil and src:find("enabled%s*=%s*true") ~= nil)
check("size = 1024 * 1024 (1MB threshold)", src:find("size%s*=%s*1024%s*%*%s*1024") ~= nil)
check("setup function defined", src:find("setup%s*=%s*function%(ctx%)") ~= nil)

-- 3. NoMatchParen is wrapped in vim.schedule (key fix for E201)
print("\n[3] NoMatchParen deferred via vim.schedule")
local setup_block = src:match("setup%s*=%s*function%(ctx%)(.-)\n%s*end,")
check("setup block found", setup_block ~= nil)
if setup_block then
  local schedule_block = setup_block:match("vim%.schedule%(function%(%)(.-)\n%s*end%)")
  check("vim.schedule block contains NoMatchParen",
    schedule_block ~= nil and schedule_block:find("NoMatchParen") ~= nil)
end

-- 4. Binary file detection autocmd
print("\n[4] Binary file detection autocmd")
check("binary_file_detection augroup in source", src:find('"binary_file_detection"') ~= nil)
check("BufReadPost autocmd for binary detection", src:find('nvim_create_autocmd%("BufReadPost"') ~= nil)
check("binary_extensions list present", src:find("binary_extensions") ~= nil)

-- 5. User commands
print("\n[5] User commands")
check("BigFileInfo command defined", src:find('nvim_create_user_command%("BigFileInfo"') ~= nil)
check("BigFileOverride command defined", src:find('nvim_create_user_command%("BigFileOverride"') ~= nil)

-- 6. Feature disables in setup
print("\n[6] Feature disables in setup function")
if setup_block then
  check("swapfile disabled", setup_block:find("swapfile%s*=%s*false") ~= nil)
  check("undofile disabled", setup_block:find("undofile%s*=%s*false") ~= nil)
  check("copilot_enabled disabled", setup_block:find("copilot_enabled%s*=%s*false") ~= nil)
  check("autosave_disable set", setup_block:find("autosave_disable%s*=%s*true") ~= nil)
  check("cmp buffer disable", setup_block:find('require%("cmp"%)') ~= nil)
  check("ufo detach", setup_block:find('require%("ufo"%)%.detach') ~= nil)
  check("ibl disable", setup_block:find('require%("ibl"%)') ~= nil)
  check("local-highlight detach", setup_block:find('require%("local%-highlight"%)%.detach') ~= nil)
  check("syntax restore for real filetype", setup_block:find("ctx%.ft") ~= nil)
end

-- 7. No reference to LunarVim/bigfile.nvim remains
print("\n[7] No LunarVim/bigfile.nvim references remain")
check("No LunarVim/bigfile.nvim in source", src:find("LunarVim/bigfile") == nil)
check("No require('bigfile') in source", src:find('require%("bigfile"%)') == nil)

-- Summary
print("\n=== Results ===")
if #errors == 0 then
  print("All checks passed!")
  vim.cmd("qa!")
else
  print(string.format("%d check(s) FAILED:", #errors))
  for _, e in ipairs(errors) do
    print("  - " .. e)
  end
  vim.cmd("cq!")
end
