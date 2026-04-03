-- nvim-runner/tests/test_http_spec.lua
-- Comprehensive tests for nvim-runner HTTP parser and curl command builder
-- Run: cd nvim-runner && nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_http_spec.lua" -c "qa!"

local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local fixtures_dir = test_dir .. "/fixtures"

-- Test framework (same pattern as test_runner_spec.lua)
local results = {}
local pass_count = 0
local fail_count = 0

local function record(status, name, detail)
  if status == "PASS" then
    pass_count = pass_count + 1
  elseif status == "FAIL" then
    fail_count = fail_count + 1
  end
  local msg = string.format("[%s] %s", status, name)
  if detail then
    msg = msg .. " -- " .. detail
  end
  table.insert(results, msg)
  io.write(msg .. "\n")
  io.flush()
end

local function assert_eq(got, expected, test_name, detail)
  if got == expected then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, string.format("expected=%s, got=%s", tostring(expected), tostring(got)))
    return false
  end
end

local function assert_true(val, test_name, detail)
  if val then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, detail or "expected truthy value")
    return false
  end
end

local function assert_nil(val, test_name, detail)
  if val == nil then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, string.format("expected nil, got=%s", tostring(val)))
    return false
  end
end

local function assert_match(str, pattern, test_name, detail)
  if type(str) == "string" and str:match(pattern) then
    record("PASS", test_name, detail)
    return true
  else
    record("FAIL", test_name, string.format("pattern=%s not found in: %s", pattern, tostring(str)))
    return false
  end
end

-- Load the HTTP module
local http = require("nvim-runner.http")

io.write("\n========================================\n")
io.write("  nvim-runner HTTP test suite\n")
io.write("========================================\n\n")

-- ============================================
-- Section 1: parse_request — Basic parsing
-- ============================================

io.write("\n--- parse_request: basic parsing ---\n\n")

do
  local req, err = http.parse_request("GET https://httpbin.org/get HTTP/1.1\nAccept: application/json\n")
  assert_eq(req.method, "GET", "parse GET method")
  assert_eq(req.url, "https://httpbin.org/get", "parse GET url")
  assert_eq(req.http_version, "HTTP/1.1", "parse HTTP version")
  assert_eq(req.headers["Accept"], "application/json", "parse Accept header")
  assert_nil(req.body, "GET has no body")
  assert_nil(err, "no parse error for valid GET")
end

do
  local req, err = http.parse_request("POST https://httpbin.org/post\nContent-Type: application/json\n\n{\"key\": \"value\"}\n")
  assert_eq(req.method, "POST", "parse POST method")
  assert_eq(req.url, "https://httpbin.org/post", "parse POST url")
  assert_nil(req.http_version, "no HTTP version when omitted")
  assert_eq(req.headers["Content-Type"], "application/json", "parse Content-Type header")
  assert_eq(req.body, '{"key": "value"}', "parse POST body")
  assert_nil(err, "no parse error for valid POST")
end

do
  local req, err = http.parse_request("DELETE https://api.example.com/users/123\n")
  assert_eq(req.method, "DELETE", "parse DELETE method")
  assert_eq(req.url, "https://api.example.com/users/123", "parse DELETE url")
  assert_nil(req.body, "DELETE has no body")
  assert_nil(err, "no parse error for DELETE")
end

do
  local req, err = http.parse_request("PUT https://api.example.com/users/123\nContent-Type: application/json\n\n{\"name\": \"updated\"}\n")
  assert_eq(req.method, "PUT", "parse PUT method")
  assert_eq(req.body, '{"name": "updated"}', "parse PUT body")
end

do
  local req, err = http.parse_request("PATCH https://api.example.com/resource\n")
  assert_eq(req.method, "PATCH", "parse PATCH method")
end

-- ============================================
-- Section 2: parse_request — Metadata
-- ============================================

io.write("\n--- parse_request: metadata ---\n\n")

do
  local req, err = http.parse_request("# @name my-request\n# @proxy http://127.0.0.1:7891\nGET https://httpbin.org/get\n")
  assert_eq(req.name, "my-request", "parse @name metadata")
  assert_eq(req.proxy, "http://127.0.0.1:7891", "parse @proxy metadata")
  assert_eq(req.method, "GET", "method parsed after metadata")
  assert_nil(err, "no parse error with metadata")
end

do
  local req, err = http.parse_request("# @proxy socks5://localhost:1080\nGET https://example.com\n")
  assert_eq(req.proxy, "socks5://localhost:1080", "parse socks5 proxy")
end

-- ============================================
-- Section 3: parse_request — Comments
-- ============================================

io.write("\n--- parse_request: comments ---\n\n")

do
  local req, err = http.parse_request("# This is a comment\n// Another comment\nGET https://httpbin.org/get\n")
  assert_eq(req.method, "GET", "method parsed after comments")
  assert_eq(req.url, "https://httpbin.org/get", "url parsed after comments")
  assert_nil(err, "no parse error with comments")
end

do
  local req, err = http.parse_request("# Just a comment\n// Another comment\n# Yet another\n")
  assert_nil(req, "comments-only returns nil")
  assert_true(err ~= nil, "comments-only returns error message")
end

-- ============================================
-- Section 4: parse_request — Edge cases
-- ============================================

io.write("\n--- parse_request: edge cases ---\n\n")

do
  local req, err = http.parse_request("")
  assert_nil(req, "empty string returns nil")
  assert_eq(err, "empty request", "empty string error message")
end

do
  local req, err = http.parse_request("   \n  \n  ")
  assert_nil(req, "whitespace-only returns nil")
end

do
  local req, err = http.parse_request("GET https://httpbin.org/get\n")
  assert_eq(req.method, "GET", "request with no headers")
  assert_true(next(req.headers) == nil, "headers table is empty for no headers", "got headers: " .. vim.inspect(req.headers))
  assert_nil(req.body, "no body when no blank line separator")
end

do
  -- Multiple headers
  local text = "POST https://api.example.com/data\nContent-Type: application/json\nAuthorization: Bearer tok123\nX-Custom: hello world\n\n{\"data\": true}\n"
  local req, err = http.parse_request(text)
  assert_eq(req.headers["Content-Type"], "application/json", "multiple headers: Content-Type")
  assert_eq(req.headers["Authorization"], "Bearer tok123", "multiple headers: Authorization")
  assert_eq(req.headers["X-Custom"], "hello world", "multiple headers: X-Custom")
  assert_eq(req.body, '{"data": true}', "body after multiple headers")
end

do
  -- Multiline body
  local text = "POST https://api.example.com/data\nContent-Type: application/json\n\n{\n  \"name\": \"test\",\n  \"value\": 42\n}\n"
  local req, err = http.parse_request(text)
  assert_true(req.body ~= nil, "multiline body parsed")
  assert_match(req.body, '"name": "test"', "multiline body contains name field")
  assert_match(req.body, '"value": 42', "multiline body contains value field")
end

do
  -- URL with query parameters
  local req, err = http.parse_request("GET https://api.example.com/search?q=hello&limit=10\n")
  assert_eq(req.url, "https://api.example.com/search?q=hello&limit=10", "URL with query params preserved")
end

do
  -- Leading blank lines
  local req, err = http.parse_request("\n\nGET https://httpbin.org/get\n")
  assert_eq(req.method, "GET", "leading blank lines skipped")
  assert_eq(req.url, "https://httpbin.org/get", "url correct after leading blanks")
end

do
  -- Invalid request line
  local req, err = http.parse_request("not a valid request\n")
  assert_nil(req, "invalid request line returns nil")
  assert_true(err ~= nil, "invalid request line returns error")
end

-- ============================================
-- Section 5: parse_request — Fixtures
-- ============================================

io.write("\n--- parse_request: fixtures ---\n\n")

do
  local content = table.concat(vim.fn.readfile(fixtures_dir .. "/simple.http"), "\n")
  local req, err = http.parse_request(content)
  assert_eq(req.method, "GET", "fixture simple.http: method")
  assert_eq(req.url, "https://httpbin.org/get", "fixture simple.http: url")
  assert_eq(req.http_version, "HTTP/1.1", "fixture simple.http: version")
  assert_eq(req.headers["Accept"], "application/json", "fixture simple.http: header")
end

do
  local content = table.concat(vim.fn.readfile(fixtures_dir .. "/post_json.http"), "\n")
  local req, err = http.parse_request(content)
  assert_eq(req.method, "POST", "fixture post_json.http: method")
  assert_eq(req.name, "create-user", "fixture post_json.http: name metadata")
  assert_eq(req.headers["Content-Type"], "application/json", "fixture post_json.http: Content-Type")
  assert_true(req.body ~= nil, "fixture post_json.http: has body")
  assert_match(req.body, '"name": "test"', "fixture post_json.http: body content")
end

do
  local content = table.concat(vim.fn.readfile(fixtures_dir .. "/with_proxy.http"), "\n")
  local req, err = http.parse_request(content)
  assert_eq(req.method, "GET", "fixture with_proxy.http: method")
  assert_eq(req.proxy, "http://127.0.0.1:7891", "fixture with_proxy.http: proxy")
  assert_eq(req.name, "proxied-request", "fixture with_proxy.http: name")
end

-- ============================================
-- Section 6: extract_request_at_cursor
-- ============================================

io.write("\n--- extract_request_at_cursor ---\n\n")

do
  -- Single request — should return everything
  local lines = { "GET https://httpbin.org/get", "Accept: application/json" }
  local text = http.extract_request_at_cursor(lines, 1)
  assert_match(text, "GET https://httpbin.org/get", "single request: contains request line")
  assert_match(text, "Accept: application/json", "single request: contains header")
end

do
  -- Multi request — cursor in first block
  local lines = vim.fn.readfile(fixtures_dir .. "/multi_request.http")
  local text = http.extract_request_at_cursor(lines, 1)
  assert_match(text, "GET https://httpbin.org/get", "multi: cursor in first block returns GET")
  -- Should NOT contain the POST request
  local has_post = text:match("POST")
  assert_true(has_post == nil, "multi: first block does not contain POST", "text=" .. text)
end

do
  -- Multi request — cursor in second block
  local lines = vim.fn.readfile(fixtures_dir .. "/multi_request.http")
  -- Find line number of POST request (after first ###)
  local post_line = nil
  for i, line in ipairs(lines) do
    if line:match("^POST") then
      post_line = i
      break
    end
  end
  assert_true(post_line ~= nil, "multi: found POST line in fixture")
  if post_line then
    local text = http.extract_request_at_cursor(lines, post_line)
    assert_match(text, "POST https://httpbin.org/post", "multi: cursor in second block returns POST")
    -- Should NOT contain GET or DELETE
    assert_true(not text:match("^GET"), "multi: second block does not contain GET")
    assert_true(not text:match("DELETE"), "multi: second block does not contain DELETE")
  end
end

do
  -- Multi request — cursor in third block
  local lines = vim.fn.readfile(fixtures_dir .. "/multi_request.http")
  local delete_line = nil
  for i, line in ipairs(lines) do
    if line:match("^DELETE") then
      delete_line = i
      break
    end
  end
  assert_true(delete_line ~= nil, "multi: found DELETE line in fixture")
  if delete_line then
    local text = http.extract_request_at_cursor(lines, delete_line)
    assert_match(text, "DELETE https://httpbin.org/delete", "multi: cursor in third block returns DELETE")
    assert_true(not text:match("POST"), "multi: third block does not contain POST")
  end
end

do
  -- Cursor on ### separator line — should return block above
  local lines = vim.fn.readfile(fixtures_dir .. "/multi_request.http")
  local sep_line = nil
  for i, line in ipairs(lines) do
    if line:match("^###") then
      sep_line = i
      break
    end
  end
  assert_true(sep_line ~= nil, "multi: found ### separator")
  if sep_line then
    local text = http.extract_request_at_cursor(lines, sep_line)
    -- Should get the block above the separator
    assert_match(text, "GET https://httpbin.org/get", "cursor on ###: returns block above")
  end
end

-- ============================================
-- Section 7: build_curl_command (via parse + manual build)
-- ============================================

io.write("\n--- curl command generation ---\n\n")

-- We can't easily test build_curl_command directly because it reads the buffer,
-- but we can test the logic by parsing and building commands from the parsed struct.
-- Let's test the core logic by creating a helper that mimics what build_curl_command does.

local function build_cmd_from_text(text, runner)
  runner = runner or "curl"
  local request, err = http.parse_request(text)
  if not request then
    return nil, err
  end

  local parts = {}
  table.insert(parts, vim.fn.shellescape(runner))
  table.insert(parts, "-s")
  table.insert(parts, "-i")
  table.insert(parts, "-X")
  table.insert(parts, vim.fn.shellescape(request.method))

  for name, value in pairs(request.headers) do
    table.insert(parts, "-H")
    table.insert(parts, vim.fn.shellescape(name .. ": " .. value))
  end

  if request.body then
    table.insert(parts, "-d")
    table.insert(parts, vim.fn.shellescape(request.body))
  end

  if request.proxy then
    table.insert(parts, "-x")
    table.insert(parts, vim.fn.shellescape(request.proxy))
  end

  table.insert(parts, vim.fn.shellescape(request.url))

  return table.concat(parts, " ")
end

do
  local cmd = build_cmd_from_text("GET https://httpbin.org/get\n")
  assert_match(cmd, "curl", "curl cmd: contains curl")
  assert_match(cmd, "%-s", "curl cmd: contains -s (silent)")
  assert_match(cmd, "%-i", "curl cmd: contains -i (include headers)")
  assert_match(cmd, "%-X", "curl cmd: contains -X")
  assert_match(cmd, "GET", "curl cmd: contains GET method")
  assert_match(cmd, "httpbin.org/get", "curl cmd: contains URL")
  -- Should NOT contain -d (no body)
  assert_true(not cmd:match("%-d "), "curl cmd GET: no -d flag")
end

do
  local cmd = build_cmd_from_text("POST https://httpbin.org/post\nContent-Type: application/json\n\n{\"key\": \"value\"}\n")
  assert_match(cmd, "POST", "curl cmd POST: contains POST")
  assert_match(cmd, "%-H", "curl cmd POST: contains -H for headers")
  assert_match(cmd, "Content%-Type: application/json", "curl cmd POST: contains Content-Type header")
  assert_match(cmd, "%-d", "curl cmd POST: contains -d for body")
end

do
  local cmd = build_cmd_from_text("# @proxy http://127.0.0.1:7891\nGET https://httpbin.org/get\n")
  assert_match(cmd, "%-x", "curl cmd proxy: contains -x flag")
  assert_match(cmd, "127.0.0.1:7891", "curl cmd proxy: contains proxy URL")
end

do
  -- Shell injection prevention: URL with dangerous chars
  local cmd = build_cmd_from_text("GET https://example.com/$(whoami)\n")
  -- The URL should be shell-escaped (wrapped in quotes)
  assert_true(cmd ~= nil, "curl cmd injection: command built successfully")
  -- shellescape wraps in single quotes, which prevents $(whoami) expansion
  assert_match(cmd, "'https://example.com/%$%(whoami%)'", "curl cmd injection: URL is shell-escaped")
end

do
  -- Shell injection prevention: body with backticks
  local cmd = build_cmd_from_text("POST https://example.com\nContent-Type: text/plain\n\n`whoami`\n")
  assert_true(cmd ~= nil, "curl cmd body injection: command built successfully")
  -- Body should be shell-escaped
  assert_match(cmd, "%-d", "curl cmd body injection: has -d flag")
end

do
  -- No proxy when not specified
  local cmd = build_cmd_from_text("GET https://httpbin.org/get\n")
  assert_true(not cmd:match("%-x "), "curl cmd no proxy: no -x flag when proxy not set")
end

-- ============================================
-- Section 8: build_curl_command integration test
-- ============================================

io.write("\n--- build_curl_command integration ---\n\n")

do
  -- Create a buffer with .http content and test build_curl_command
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "GET https://httpbin.org/get",
    "Accept: application/json",
  })
  vim.bo[buf].filetype = "http"
  -- Set cursor to line 1
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local cmd = http.build_curl_command("curl", "")
  assert_true(cmd ~= nil, "integration: build_curl_command returns a command")
  if cmd then
    assert_match(cmd, "curl", "integration: command contains curl")
    assert_match(cmd, "GET", "integration: command contains GET")
    assert_match(cmd, "httpbin.org/get", "integration: command contains URL")
    assert_match(cmd, "Accept: application/json", "integration: command contains header")
  end

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Integration test: multi-request file, cursor on second request
  local lines = vim.fn.readfile(fixtures_dir .. "/multi_request.http")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"

  -- Find POST line
  local post_line = nil
  for i, line in ipairs(lines) do
    if line:match("^POST") then
      post_line = i
      break
    end
  end

  if post_line then
    vim.api.nvim_win_set_cursor(0, { post_line, 0 })
    local cmd = http.build_curl_command("curl", "")
    assert_true(cmd ~= nil, "integration multi: build_curl_command returns a command")
    if cmd then
      assert_match(cmd, "POST", "integration multi: command contains POST")
      assert_match(cmd, "httpbin.org/post", "integration multi: command contains post URL")
      -- Should NOT contain GET url
      assert_true(not cmd:match("httpbin.org/get"), "integration multi: does not contain GET URL")
    end
  end

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Integration test: request with proxy metadata
  local lines = vim.fn.readfile(fixtures_dir .. "/with_proxy.http")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local cmd = http.build_curl_command("curl", "")
  assert_true(cmd ~= nil, "integration proxy: build_curl_command returns a command")
  if cmd then
    assert_match(cmd, "%-x", "integration proxy: command contains -x flag")
    assert_match(cmd, "127.0.0.1:7891", "integration proxy: command contains proxy URL")
  end

  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- Section 9: vim.g.http_proxy fallback
-- ============================================

io.write("\n--- vim.g.http_proxy fallback ---\n\n")

do
  -- Set global proxy
  vim.g.http_proxy = "http://global-proxy:8080"

  local lines = { "GET https://httpbin.org/get" }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local cmd = http.build_curl_command("curl", "")
  assert_true(cmd ~= nil, "global proxy: build_curl_command returns a command")
  if cmd then
    assert_match(cmd, "%-x", "global proxy: command contains -x flag")
    assert_match(cmd, "global%-proxy:8080", "global proxy: command contains global proxy URL")
  end

  -- Clean up
  vim.g.http_proxy = nil
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- In-file proxy should override vim.g.http_proxy
  vim.g.http_proxy = "http://global-proxy:8080"

  local lines = vim.fn.readfile(fixtures_dir .. "/with_proxy.http")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local cmd = http.build_curl_command("curl", "")
  assert_true(cmd ~= nil, "proxy override: build_curl_command returns a command")
  if cmd then
    -- Should use the in-file proxy, not the global one
    assert_match(cmd, "127.0.0.1:7891", "proxy override: in-file proxy takes precedence")
    assert_true(not cmd:match("global%-proxy"), "proxy override: global proxy not used")
  end

  vim.g.http_proxy = nil
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- Section 10: Filetype detection
-- ============================================

io.write("\n--- filetype detection ---\n\n")

do
  -- Test that .http extension maps to filetype "http"
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "test_request.http")
  vim.cmd("filetype detect")
  assert_eq(vim.bo[buf].filetype, "http", "filetype: .http extension detected as http")
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Test that .rest extension maps to filetype "http"
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "test_request.rest")
  vim.cmd("filetype detect")
  assert_eq(vim.bo[buf].filetype, "http", "filetype: .rest extension detected as http")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- ============================================
-- Section 11: Config defaults
-- ============================================

io.write("\n--- config defaults ---\n\n")

do
  local config = require("nvim-runner.config")
  local http_runner = config.options.runners.http
  assert_true(http_runner ~= nil, "config: http runner exists in defaults")
  if http_runner then
    assert_eq(http_runner.runner, "curl", "config: http runner uses curl")
    assert_eq(type(http_runner.template), "function", "config: http template is a function")
    assert_eq(http_runner.timeout, 30000, "config: http timeout is 30000ms")
  end
end

-- ============================================
-- Summary
-- ============================================

io.write("\n========================================\n")
io.write(string.format("  Results: %d passed, %d failed (total: %d)\n", pass_count, fail_count, pass_count + fail_count))
io.write("========================================\n\n")

if fail_count > 0 then
  io.write("FAILED TESTS:\n")
  for _, r in ipairs(results) do
    if r:match("^%[FAIL%]") then
      io.write("  " .. r .. "\n")
    end
  end
  io.write("\n")
  -- Exit with error code
  vim.cmd("cquit!")
end
