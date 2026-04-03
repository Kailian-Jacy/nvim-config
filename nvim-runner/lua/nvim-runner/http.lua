-- nvim-runner/lua/nvim-runner/http.lua
-- HTTP request parser and curl command builder for .http files
-- Supports VS Code REST Client / JetBrains HTTP Client format (MVP subset)

local M = {}

---@class HttpRequest
---@field method string          HTTP method (GET, POST, PUT, etc.)
---@field url string             Full URL
---@field http_version string?   HTTP version (e.g. "HTTP/1.1")
---@field headers table<string, string>  Header name-value pairs
---@field body string?           Request body (nil if none)
---@field proxy string?          Proxy URL from # @proxy metadata
---@field name string?           Request name from # @name metadata

--- Parse metadata comments (# @key value) from lines.
--- Stops at the first non-comment, non-blank line.
---@param lines string[]
---@return table<string, string> metadata key-value pairs
---@return number first_non_meta_line 1-indexed line where metadata ends
local function parse_metadata(lines)
  local meta = {}
  local start = 1
  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    -- blank lines before request line — skip
    if trimmed == "" then
      start = i + 1
    -- metadata comment: # @key value
    elseif trimmed:match("^#%s*@(%S+)%s+(.+)$") then
      local key, value = trimmed:match("^#%s*@(%S+)%s+(.+)$")
      meta[key] = value
      start = i + 1
    -- metadata flag: # @key (no value, treated as boolean true)
    elseif trimmed:match("^#%s*@(%S+)%s*$") then
      local key = trimmed:match("^#%s*@(%S+)%s*$")
      meta[key] = true
      start = i + 1
    -- regular comment: # ... or // ...
    elseif trimmed:match("^#") or trimmed:match("^//") then
      start = i + 1
    else
      -- non-comment, non-blank line — this is the request line
      break
    end
  end
  return meta, start
end

--- Validate HTTP version string (e.g. "HTTP/1.1", "HTTP/2").
---@param version string
---@return boolean
local function is_valid_http_version(version)
  return version:match("^HTTP/%d") ~= nil
end

--- Strip \r from end of line (handle CRLF)
---@param line string
---@return string
local function strip_cr(line)
  local result = line:gsub("\r$", "")
  return result
end

--- Parse a single HTTP request from text.
---@param text string  raw text of one request block
---@return HttpRequest? parsed request, or nil on error
---@return string? error message if parsing failed
function M.parse_request(text)
  if not text or text:match("^%s*$") then
    return nil, "empty request"
  end

  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, strip_cr(line))
  end

  -- Extract metadata from leading comments
  local meta, start = parse_metadata(lines)

  -- Find request line: METHOD URL [HTTP-Version]
  local method, url, http_version
  local request_line_idx
  for i = start, #lines do
    local trimmed = lines[i]:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^//") then
      -- Try to match request line
      method, url, http_version = trimmed:match("^(%u+)%s+(%S+)%s*(.*)")
      if method and url then
        if http_version and http_version:match("^%s*$") then
          http_version = nil
        elseif http_version then
          http_version = http_version:match("^%s*(.-)%s*$")
          -- Validate HTTP version format
          if not is_valid_http_version(http_version) then
            return nil, "invalid HTTP version: " .. http_version
          end
        end
        request_line_idx = i
        break
      else
        return nil, "invalid request line: " .. trimmed
      end
    end
  end

  if not method then
    return nil, "no request line found"
  end

  -- Parse headers: lines after request line until first blank line.
  -- Stop header parsing at the first non-header line (garbage = end of headers).
  local headers = {}
  local body_start = nil
  for i = request_line_idx + 1, #lines do
    local trimmed = lines[i]:match("^%s*(.-)%s*$")
    if trimmed == "" then
      body_start = i + 1
      break
    end
    -- Header: Name: Value (value may be empty)
    local hname, hvalue = trimmed:match("^(%S+):%s*(.*)$")
    if hname then
      headers[hname] = hvalue
    else
      -- Non-header line before blank separator — treat as start of body.
      -- This prevents garbage lines from being silently skipped while
      -- headers after them continue to be parsed.
      body_start = i
      break
    end
  end

  -- Parse body: everything after the blank line separator
  local body = nil
  if body_start and body_start <= #lines then
    local body_lines = {}
    for i = body_start, #lines do
      table.insert(body_lines, lines[i])
    end
    local body_text = table.concat(body_lines, "\n")
    -- Trim trailing whitespace/newlines
    body_text = body_text:match("^(.-)%s*$")
    if body_text and body_text ~= "" then
      body = body_text
    end
  end

  ---@type HttpRequest
  local request = {
    method = method,
    url = url,
    http_version = http_version,
    headers = headers,
    body = body,
    proxy = meta.proxy or nil,
    name = meta.name or nil,
    debug = meta.debug or nil,
    timeout = meta.timeout or nil,
  }

  return request, nil
end

--- Extract the request block around the cursor position.
--- In multi-request files, requests are separated by ### lines.
---@param lines string[]  all buffer lines
---@param cursor_line number  1-indexed cursor line
---@return string  the text of the request block containing the cursor
function M.extract_request_at_cursor(lines, cursor_line)
  -- Defensive: handle empty buffer or out-of-bounds cursor
  if not lines or #lines == 0 then
    return ""
  end
  -- Clamp cursor_line to valid range
  if cursor_line < 1 then
    cursor_line = 1
  elseif cursor_line > #lines then
    cursor_line = #lines
  end

  -- Find the ### boundaries around cursor_line
  local block_start = 1
  local block_end = #lines

  -- Scan backwards from cursor to find start boundary
  for i = cursor_line, 1, -1 do
    local trimmed = lines[i]:match("^%s*(.-)%s*$")
    if trimmed:match("^###") then
      block_start = i + 1
      break
    end
  end

  -- Scan forwards from cursor to find end boundary
  for i = cursor_line, #lines do
    local trimmed = lines[i]:match("^%s*(.-)%s*$")
    if trimmed:match("^###") and i > cursor_line then
      block_end = i - 1
      break
    -- Also handle cursor ON a ### line: treat as belonging to the block above
    elseif trimmed:match("^###") and i == cursor_line then
      -- Cursor is on the separator — use the block above
      block_end = i - 1
      -- Re-scan backwards from i-1 for start
      block_start = 1
      for j = i - 1, 1, -1 do
        local t = lines[j]:match("^%s*(.-)%s*$")
        if t:match("^###") then
          block_start = j + 1
          break
        end
      end
      break
    end
  end

  -- Clamp: if start > end after separator logic, return empty
  if block_start > block_end then
    return ""
  end

  local block = {}
  for i = block_start, block_end do
    table.insert(block, lines[i])
  end

  return table.concat(block, "\n")
end

--- Resolve proxy URL with cascade: in-file @proxy > vim.g.http_proxy > env vars (curl default)
---@param request_proxy string?  proxy from # @proxy metadata
---@return string?  proxy URL to use, or nil to let curl use env vars
local function resolve_proxy(request_proxy)
  -- 1. In-file metadata (highest priority)
  if request_proxy and request_proxy ~= "" then
    return request_proxy
  end

  -- 2. Neovim global variable
  local g_proxy = vim.g.http_proxy
  if g_proxy and type(g_proxy) == "string" and g_proxy ~= "" then
    return g_proxy
  end

  -- 3. Let curl handle env vars automatically
  return nil
end

--- Build a curl command string from a runner and raw .http buffer text.
--- This is the template function called by nvim-runner.
---@param runner string  the runner executable (usually "curl")
---@param text string  the raw buffer text of the .http file
---@return string?  the shell command to execute, or nil on error
function M.build_curl_command(runner, text)
  -- Get cursor position for multi-request files
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Extract the request block at cursor
  local request_text = M.extract_request_at_cursor(lines, cursor_line)

  -- Parse the request
  local request, err = M.parse_request(request_text)
  if not request then
    vim.notify("HTTP parse error: " .. (err or "unknown"), vim.log.levels.ERROR)
    return nil
  end

  -- File body support: `< filepath` reads file contents as body
  -- Only single-line bodies can be file references
  if request.body then
    local trimmed_body = request.body:match("^(.-)%s*$")
    if not trimmed_body:find("\n") then
      local filepath = trimmed_body:match("^<%s+(.+)$")
      if filepath then
        filepath = filepath:match("^(.-)%s*$") -- trim trailing spaces from path
        filepath = vim.fn.expand(filepath) -- expand ~ and $HOME
        if not filepath:match("^/") then
          -- Relative path: resolve against buffer directory
          local buf_dir = vim.fn.expand("%:p:h")
          filepath = buf_dir .. "/" .. filepath
        end
        if vim.fn.filereadable(filepath) == 1 then
          local file_lines = vim.fn.readfile(filepath)
          request.body = table.concat(file_lines, "\n")
        else
          vim.notify("HTTP file body: file not found: " .. filepath, vim.log.levels.ERROR)
          return nil
        end
      end
    end
  end

  -- Build curl command parts
  local parts = {}
  table.insert(parts, vim.fn.shellescape(runner))
  table.insert(parts, "-sS")
  table.insert(parts, "-i")
  table.insert(parts, "-w")
  table.insert(parts, vim.fn.shellescape("\n--- %{http_code} | %{time_total}s ---"))

  -- @timeout: set curl --max-time and buffer-local runner timeout
  if request.timeout then
    local timeout_s = tonumber(request.timeout)
    if timeout_s and timeout_s > 0 then
      vim.b.runner_timeout = math.floor(timeout_s * 1000)
      table.insert(parts, "--max-time")
      table.insert(parts, tostring(timeout_s))
    end
  end

  table.insert(parts, "-X")
  table.insert(parts, vim.fn.shellescape(request.method))

  -- Headers
  for name, value in pairs(request.headers) do
    table.insert(parts, "-H")
    table.insert(parts, vim.fn.shellescape(name .. ": " .. value))
  end

  -- Body
  if request.body then
    table.insert(parts, "-d")
    table.insert(parts, vim.fn.shellescape(request.body))
  end

  -- Proxy
  local proxy = resolve_proxy(request.proxy)
  if proxy then
    table.insert(parts, "-x")
    table.insert(parts, vim.fn.shellescape(proxy))
  end

  -- URL (last)
  table.insert(parts, vim.fn.shellescape(request.url))

  -- Debug mode: add verbose flag and notify the command
  if request.debug then
    table.insert(parts, "-v")
    local cmd = table.concat(parts, " ")
    vim.notify("DEBUG curl command:\n" .. cmd, vim.log.levels.INFO)
    return cmd
  end

  return table.concat(parts, " ")
end

return M
