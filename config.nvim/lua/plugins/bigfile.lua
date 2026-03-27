-- Big file and binary file handling.
-- When opening large files or binary files, automatically disable expensive features
-- to keep Neovim responsive. Addresses nvim-config#3.

---@param bytes number
---@return string
local function format_size(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format("%.1f MB", bytes / (1024 * 1024))
  else
    return string.format("%.1f GB", bytes / (1024 * 1024 * 1024))
  end
end

return {
  {
    "LunarVim/bigfile.nvim",
    lazy = false,
    priority = 900, -- Load early to intercept file opens
    config = function()
      -- Size threshold in bytes (default 1MB)
      local bigfile_size_threshold = vim.g.bigfile_size_threshold or (1024 * 1024) -- 1 MB

      -- Binary file extensions to always treat as big/binary
      local binary_extensions = {
        "bin", "o", "obj", "exe", "a", "so", "dylib", "dll",
        "class", "pyc", "pyo",
        "pdf", "doc", "docx", "xls", "xlsx",
        "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp",
        "mp3", "mp4", "avi", "mkv", "mov", "flv", "wmv", "wav", "flac",
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar",
        "wasm", "dat",
      }

      --- Check if a buffer contains binary content (null bytes in first lines)
      ---@param bufnr number
      ---@return boolean
      local function is_binary_content(bufnr)
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, math.min(100, line_count), false)
        if not ok then
          return false
        end
        for _, line in ipairs(lines) do
          if line:find("%z") then
            return true
          end
          -- Check for high concentration of non-printable characters
          local total = #line
          if total > 0 then
            local check_len = math.min(total, 512)
            local non_printable = 0
            for i = 1, check_len do
              local byte = line:byte(i)
              if byte < 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
                non_printable = non_printable + 1
              end
            end
            if non_printable / check_len > 0.3 then
              return true
            end
          end
        end
        return false
      end

      --- Check if file extension is a known binary type
      ---@param filepath string
      ---@return boolean
      local function is_binary_extension(filepath)
        local ext = vim.fn.fnamemodify(filepath, ":e"):lower()
        return vim.tbl_contains(binary_extensions, ext)
      end

      --- Disable expensive features for the current buffer
      ---@param bufnr number
      ---@param reason string
      local function disable_expensive_features(bufnr, reason)
        vim.b[bufnr].bigfile_detected = true
        vim.b[bufnr].bigfile_reason = reason

        -- Disable treesitter highlighting
        pcall(function()
          vim.treesitter.stop(bufnr)
        end)

        -- Detach LSP clients
        vim.schedule(function()
          local clients = vim.lsp.get_clients({ bufnr = bufnr })
          for _, client in ipairs(clients) do
            pcall(vim.lsp.buf_detach_client, bufnr, client.id)
          end
        end)

        -- Disable various buffer-local features
        vim.bo[bufnr].swapfile = false
        vim.bo[bufnr].undofile = false

        -- Disable syntax highlighting (fallback)
        vim.bo[bufnr].syntax = ""

        -- Disable folding for this buffer
        pcall(function()
          vim.wo.foldmethod = "manual"
          vim.wo.foldenable = false
        end)

        -- Disable indent-blankline for this buffer
        pcall(function()
          if vim.g.is_plugin_loaded and vim.g.is_plugin_loaded("indent-blankline.nvim") then
            require("ibl").setup_buffer(bufnr, { enabled = false })
          end
        end)

        -- Disable local-highlight
        pcall(function()
          if vim.g.is_plugin_loaded and vim.g.is_plugin_loaded("local-highlight.nvim") then
            require("local-highlight").detach(bufnr)
          end
        end)

        -- Disable nvim-ufo folding
        pcall(function()
          if vim.g.is_plugin_loaded and vim.g.is_plugin_loaded("nvim-ufo") then
            require("ufo").detach(bufnr)
          end
        end)

        -- Disable matchparen
        pcall(vim.cmd, "NoMatchParen")

        -- Disable copilot for this buffer
        vim.b[bufnr].copilot_enabled = false

        -- Disable nvim-cmp for this buffer
        pcall(function()
          if package.loaded["cmp"] then
            require("cmp").setup.buffer({ enabled = false })
          end
        end)

        -- Disable auto-save for this buffer
        vim.b[bufnr].autosave_disable = true

        vim.notify(
          string.format("Big file detected (%s). Disabled expensive features.", reason),
          vim.log.levels.INFO
        )
      end

      -- Configure bigfile.nvim
      require("bigfile").setup({
        filesize = math.floor(bigfile_size_threshold / (1024 * 1024)), -- Convert to MiB for bigfile.nvim
        pattern = { "*" },
        features = {
          "indent_blankline",
          "illuminate",
          "lsp",
          "treesitter",
          "syntax",
          "matchparen",
          "vimopts",
          -- filetype is intentionally NOT disabled so autocmds still work
        },
      })

      -- Additional autocmd for binary detection (bigfile.nvim only handles size)
      vim.api.nvim_create_autocmd({ "BufReadPost" }, {
        group = vim.api.nvim_create_augroup("binary_file_detection", { clear = true }),
        callback = function(args)
          local bufnr = args.buf
          local filepath = vim.api.nvim_buf_get_name(bufnr)

          if filepath == "" or vim.b[bufnr].bigfile_detected then
            return
          end

          -- Check binary extension first (fast path)
          if is_binary_extension(filepath) then
            disable_expensive_features(bufnr, "binary extension: " .. vim.fn.fnamemodify(filepath, ":e"))
            return
          end

          -- Check for binary content (slower, done last)
          if is_binary_content(bufnr) then
            disable_expensive_features(bufnr, "binary content detected")
            return
          end
        end,
      })

      -- Also intercept BufReadPre for very large files to prevent loading issues
      vim.api.nvim_create_autocmd({ "BufReadPre" }, {
        group = vim.api.nvim_create_augroup("bigfile_precheck", { clear = true }),
        callback = function(args)
          local filepath = args.match
          if filepath == "" then
            return
          end

          local ok, stats = pcall(vim.uv.fs_stat, filepath)
          if ok and stats and stats.size then
            -- For extremely large files (>10MB), set buffer options before loading
            if stats.size > bigfile_size_threshold * 10 then
              vim.bo[args.buf].swapfile = false
              vim.bo[args.buf].undofile = false
              vim.b[args.buf].bigfile_detected = true
            end
          end
        end,
      })

      -- User command to check bigfile status
      vim.api.nvim_create_user_command("BigFileInfo", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(bufnr)

        if filepath == "" then
          vim.notify("No file in current buffer", vim.log.levels.INFO)
          return
        end

        local ok, stats = pcall(vim.uv.fs_stat, filepath)
        local size_str = "unknown"
        if ok and stats then
          size_str = format_size(stats.size)
        end

        local is_big = vim.b[bufnr].bigfile_detected or false
        local reason = vim.b[bufnr].bigfile_reason or "N/A"

        local lines = {
          "File: " .. filepath,
          "Size: " .. size_str,
          "Big file: " .. tostring(is_big),
          "Reason: " .. reason,
          "Threshold: " .. format_size(bigfile_size_threshold),
        }
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "Show big file detection info for current buffer" })

      -- User command to force-enable features on current buffer
      vim.api.nvim_create_user_command("BigFileOverride", function()
        local bufnr = vim.api.nvim_get_current_buf()
        vim.b[bufnr].bigfile_detected = false
        vim.b[bufnr].bigfile_reason = nil

        -- Re-enable treesitter
        pcall(function()
          vim.treesitter.start(bufnr)
        end)

        -- Re-enable syntax
        vim.bo[bufnr].syntax = "on"

        -- Re-enable undofile
        vim.bo[bufnr].undofile = true

        vim.notify("Big file protections overridden for this buffer.", vim.log.levels.INFO)
      end, { desc = "Override big file detection and re-enable features" })
    end,
  },
}
