-- nvim-runner/lua/nvim-runner/test_runner.lua
-- RunTest logic: discover and run *_vimtest.lua files

local M = {}

--- Run all *_vimtest.lua files in the current working directory
function M.run()
  local cwd = vim.fn.getcwd()
  local test_files = vim.fn.globpath(cwd, "*_vimtest.lua", true, true)
  if #test_files == 0 then
    vim.notify("No *_vimtest.lua files found in " .. cwd, vim.log.levels.INFO)
    return
  end

  for _, file in ipairs(test_files) do
    vim.notify("---Testing file " .. file .. " ---", vim.log.levels.INFO)
    local success, result = pcall(dofile, file)
    if not success then
      vim.notify("---Error executing test file " .. file .. ": " .. result, vim.log.levels.ERROR)
    else
      if result ~= nil then
        vim.notify("---Test result: " .. tostring(result), vim.log.levels.INFO)
      end
    end
  end
end

return M
