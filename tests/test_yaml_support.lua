-- test_yaml_support.lua
-- Validates YAML support fixes for issue #57
-- Run: nvim --headless -u NORC -l tests/test_yaml_support.lua

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  ✅ " .. name)
  else
    failed = failed + 1
    print("  ❌ " .. name .. ": " .. tostring(err))
  end
end

print("\n=== YAML Support Tests ===\n")

-- We test the Lua source files directly (static analysis) since we can't
-- load the full plugin stack in headless mode without all dependencies.

local lsp_path = "config.nvim/lua/plugins/lsp.lua"
local lsp_src = io.open(lsp_path, "r")
assert(lsp_src, "Cannot open " .. lsp_path)
local lsp_code = lsp_src:read("*a")
lsp_src:close()

-- P1: yamlls has capabilities and settings
test("yamlls setup includes cmp_nvim_lsp capabilities", function()
  assert(lsp_code:find("yamlls%.setup"), "yamlls.setup not found")
  -- Find the yamlls setup block
  local setup_start = lsp_code:find("yamlls%.setup")
  local after_setup = lsp_code:sub(setup_start, setup_start + 600)
  assert(after_setup:find("cmp_nvim_lsp%.default_capabilities"),
    "yamlls setup missing cmp_nvim_lsp.default_capabilities()")
end)

test("yamlls setup includes schemaStore settings", function()
  local setup_start = lsp_code:find("yamlls%.setup")
  local after_setup = lsp_code:sub(setup_start, setup_start + 600)
  assert(after_setup:find("schemaStore"), "yamlls setup missing schemaStore settings")
  assert(after_setup:find("schemastore%.org"), "yamlls setup missing schemaStore URL")
end)

test("yamlls setup includes format, validate, hover, completion", function()
  local setup_start = lsp_code:find("yamlls%.setup")
  local after_setup = lsp_code:sub(setup_start, setup_start + 600)
  assert(after_setup:find('format%s*=%s*{%s*enable%s*=%s*true'), "yamlls missing format.enable")
  assert(after_setup:find('validate%s*=%s*true'), "yamlls missing validate")
  assert(after_setup:find('hover%s*=%s*true'), "yamlls missing hover")
  assert(after_setup:find('completion%s*=%s*true'), "yamlls missing completion")
end)

-- P2: textobjects setup is guarded
test("textobjects setup is guarded with type check", function()
  assert(lsp_code:find('type%(ts_textobjects%.setup%)%s*==%s*"function"')
      or lsp_code:find("type%(ts_textobjects.setup%)"),
    "textobjects setup not guarded with type check")
end)

test("textobjects has fallback for old nvim-treesitter.configs", function()
  assert(lsp_code:find('nvim%-treesitter%.configs'),
    "textobjects missing fallback to nvim-treesitter.configs")
end)

-- P3: conform has yaml formatter
test("conform formatters_by_ft includes yaml", function()
  -- Look for yaml in formatters_by_ft
  local fmt_start = lsp_code:find("formatters_by_ft")
  assert(fmt_start, "formatters_by_ft not found")
  local fmt_block = lsp_code:sub(fmt_start, fmt_start + 800)
  assert(fmt_block:find('yaml%s*='), "yaml not in formatters_by_ft")
end)

test("conform yaml formatter uses lsp_format fallback", function()
  local fmt_start = lsp_code:find("formatters_by_ft")
  local fmt_block = lsp_code:sub(fmt_start, fmt_start + 800)
  -- Find yaml line and check for lsp_format
  local yaml_pos = fmt_block:find('yaml%s*=')
  assert(yaml_pos, "yaml entry not found")
  local yaml_line = fmt_block:sub(yaml_pos, yaml_pos + 100)
  assert(yaml_line:find('lsp_format'), "yaml formatter missing lsp_format fallback")
end)

-- P4: nvim-lint has yaml linter
test("nvim-lint linters_by_ft includes yaml with yamllint", function()
  local lint_start = lsp_code:find("linters_by_ft")
  assert(lint_start, "linters_by_ft not found")
  local lint_block = lsp_code:sub(lint_start, lint_start + 1000)
  -- Check yaml entry exists with yamllint
  assert(lint_block:find('yaml') and lint_block:find('yamllint'),
    "yaml with yamllint not in linters_by_ft")
end)

-- P5: Mason ensure_installed includes yaml-language-server
test("Mason ensure_installed has yaml-language-server", function()
  assert(lsp_code:find('"yaml%-language%-server"'),
    "yaml-language-server not in Mason ensure_installed")
end)

test("Mason ensure_installed has yamllint", function()
  assert(lsp_code:find('"yamllint"'),
    "yamllint not in Mason ensure_installed")
end)

test("Mason ensure_installed has prettier", function()
  assert(lsp_code:find('"prettier"'),
    "prettier not in Mason ensure_installed")
end)

-- Treesitter ensure_installed includes yaml
local misc_path = "config.nvim/lua/plugins/miscellaneous.lua"
local misc_src = io.open(misc_path, "r")
assert(misc_src, "Cannot open " .. misc_path)
local misc_code = misc_src:read("*a")
misc_src:close()

test("treesitter ensure_installed includes yaml", function()
  local ei_start = misc_code:find("ensure_installed")
  assert(ei_start, "ensure_installed not found in miscellaneous.lua")
  local ei_block = misc_code:sub(ei_start, ei_start + 1000)
  assert(ei_block:find('"yaml"'), "yaml not in treesitter ensure_installed")
end)

print(string.format("\n=== Results: %d passed, %d failed ===\n", passed, failed))
if failed > 0 then
  os.exit(1)
end
