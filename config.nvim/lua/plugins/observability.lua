-- Observability for Neovim.
-- Provides startup time profiling, plugin load tracking, LSP status monitoring,
-- and performance diagnostics. Addresses nvim-config#7.

return {
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    keys = {
      {
        "<leader>iS",
        "<cmd>StartupTime<cr>",
        mode = "n",
        desc = "Profile Neovim startup time",
      },
    },
    config = function()
      vim.g.startuptime_tries = 5
    end,
  },
  {
    -- Virtual plugin for custom observability commands.
    -- Using init instead of config because lazy.nvim's config() only runs
    -- after a plugin module loads. With dir pointing to the config directory,
    -- there's no real plugin module to load, so config() never executes.
    -- init() always runs during startup regardless of plugin load state.
    dir = vim.fn.stdpath("config"),
    name = "nvim-observability",
    lazy = false,
    init = function()
      -- ============================================================
      -- 1. Startup time tracking
      -- ============================================================
      -- Record the time when Neovim started (set early in init)
      if not vim.g._startup_time_start then
        vim.g._startup_time_start = vim.fn.reltime()
      end

      vim.api.nvim_create_autocmd("UIEnter", {
        group = vim.api.nvim_create_augroup("observability_startup", { clear = true }),
        once = true,
        callback = function()
          if vim.g._startup_time_start then
            local elapsed = vim.fn.reltimefloat(vim.fn.reltime(vim.g._startup_time_start))
            vim.g._startup_time_ms = math.floor(elapsed * 1000)
          end
        end,
      })

      -- ============================================================
      -- 2. :NvimHealth — comprehensive health overview
      -- ============================================================
      vim.api.nvim_create_user_command("NvimHealth", function()
        local lines = {}
        local function add(...)
          for _, line in ipairs({ ... }) do
            table.insert(lines, line)
          end
        end

        -- Startup time
        add("═══ Neovim Health Report ═══", "")
        if vim.g._startup_time_ms then
          add(string.format("⏱  Startup time: %d ms", vim.g._startup_time_ms))
        else
          add("⏱  Startup time: (not measured, use :StartupTime for detailed profiling)")
        end
        add("")

        -- Lazy.nvim plugin stats
        local lazy_ok, lazy_config = pcall(require, "lazy.core.config")
        if lazy_ok and lazy_config.plugins then
          local total = 0
          local loaded = 0
          local load_times = {}
          for name, plugin in pairs(lazy_config.plugins) do
            total = total + 1
            if plugin._.loaded then
              loaded = loaded + 1
              if plugin._.loaded.time then
                table.insert(load_times, { name = name, time = plugin._.loaded.time })
              end
            end
          end

          add(string.format("📦 Plugins: %d loaded / %d total", loaded, total))

          -- Top 10 slowest plugins
          if #load_times > 0 then
            table.sort(load_times, function(a, b) return a.time > b.time end)
            add("", "🐌 Slowest plugins:")
            for i = 1, math.min(10, #load_times) do
              local p = load_times[i]
              add(string.format("   %6.2f ms  %s", p.time, p.name))
            end
          end
        end
        add("")

        -- LSP status
        local clients = vim.lsp.get_clients()
        if #clients > 0 then
          add(string.format("🔧 LSP clients (%d active):", #clients))
          for _, client in ipairs(clients) do
            local bufs = vim.tbl_keys(client.attached_buffers or {})
            local status = "running"
            -- Check if the client process is still alive
            if client.is_stopped and client:is_stopped() then
              status = "STOPPED"
            end
            add(string.format("   %-20s [%s] bufs: %d  pid: %s",
              client.name, status, #bufs, tostring(client.rpc and client.rpc.pid or "?")))
          end
        else
          add("🔧 LSP clients: none active")
        end
        add("")

        -- Treesitter status
        local ts_ok, ts_parsers = pcall(require, "nvim-treesitter.parsers")
        if ts_ok then
          local current_ft = vim.bo.filetype
          local has_parser = ts_parsers.has_parser(current_ft)
          add(string.format("🌲 Treesitter: parser for '%s': %s", current_ft, has_parser and "✓" or "✗"))

          -- List installed parsers count
          local installed = ts_parsers.available_parsers()
          add(string.format("   Installed parsers: %d", #installed))
        end
        add("")

        -- Memory usage
        local mem = collectgarbage("count")
        add(string.format("🧠 Lua memory: %.1f MB", mem / 1024))

        -- Buffer stats
        local bufs = vim.fn.getbufinfo({ buflisted = 1 })
        local modified = 0
        for _, buf in ipairs(bufs) do
          if buf.changed == 1 then
            modified = modified + 1
          end
        end
        add(string.format("📄 Buffers: %d listed (%d modified)", #bufs, modified))

        -- System info
        local uname = vim.uv.os_uname()
        add(string.format("💻 System: %s %s (%s)", uname.sysname, uname.release, uname.machine))
        add(string.format("   Neovim: %s", vim.version and tostring(vim.version()) or "unknown"))

        add("")
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "Show comprehensive Neovim health overview" })

      -- ============================================================
      -- 3. :LspStatus — detailed LSP information
      -- ============================================================
      vim.api.nvim_create_user_command("LspStatus", function()
        local lines = {}
        local function add(...)
          for _, line in ipairs({ ... }) do
            table.insert(lines, line)
          end
        end

        local clients = vim.lsp.get_clients()
        if #clients == 0 then
          vim.notify("No LSP clients active.", vim.log.levels.INFO)
          return
        end

        add("═══ LSP Status ═══", "")

        for _, client in ipairs(clients) do
          add(string.format("▸ %s (id: %d)", client.name, client.id))
          add(string.format("  Root: %s", client.root_dir or client.config.root_dir or "N/A"))

          -- Capabilities
          local caps = {}
          if client.server_capabilities then
            if client.server_capabilities.completionProvider then table.insert(caps, "completion") end
            if client.server_capabilities.hoverProvider then table.insert(caps, "hover") end
            if client.server_capabilities.definitionProvider then table.insert(caps, "definition") end
            if client.server_capabilities.referencesProvider then table.insert(caps, "references") end
            if client.server_capabilities.renameProvider then table.insert(caps, "rename") end
            if client.server_capabilities.documentFormattingProvider then table.insert(caps, "format") end
            if client.server_capabilities.codeActionProvider then table.insert(caps, "codeAction") end
            if client.server_capabilities.inlayHintProvider then table.insert(caps, "inlayHint") end
          end
          if #caps > 0 then
            add("  Capabilities: " .. table.concat(caps, ", "))
          end

          -- Attached buffers
          local bufs = vim.tbl_keys(client.attached_buffers or {})
          if #bufs > 0 then
            local buf_names = {}
            for _, bufnr in ipairs(bufs) do
              local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
              if name ~= "" then
                table.insert(buf_names, name)
              else
                table.insert(buf_names, string.format("[%d]", bufnr))
              end
            end
            add("  Buffers: " .. table.concat(buf_names, ", "))
          end

          -- Process info
          if client.rpc and client.rpc.pid then
            add(string.format("  PID: %d", client.rpc.pid))
          end

          add("")
        end

        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "Show detailed LSP client status" })

      -- ============================================================
      -- 4. :PluginProfile — show plugin load times
      -- ============================================================
      vim.api.nvim_create_user_command("PluginProfile", function(opts)
        local count = tonumber(opts.args) or 20
        local lazy_ok, lazy_config = pcall(require, "lazy.core.config")
        if not lazy_ok then
          vim.notify("lazy.nvim not available", vim.log.levels.ERROR)
          return
        end

        local load_times = {}
        for name, plugin in pairs(lazy_config.plugins) do
          if plugin._.loaded and plugin._.loaded.time then
            table.insert(load_times, { name = name, time = plugin._.loaded.time })
          end
        end

        if #load_times == 0 then
          vim.notify("No plugin load times available.", vim.log.levels.INFO)
          return
        end

        table.sort(load_times, function(a, b) return a.time > b.time end)

        local lines = { string.format("═══ Plugin Load Times (top %d) ═══", math.min(count, #load_times)), "" }
        local total_time = 0
        for i = 1, math.min(count, #load_times) do
          local p = load_times[i]
          total_time = total_time + p.time
          table.insert(lines, string.format("  %6.2f ms  %s", p.time, p.name))
        end
        table.insert(lines, "")
        table.insert(lines, string.format("  Total (shown): %.2f ms", total_time))

        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "Show plugin load time profile", nargs = "?" })

      -- ============================================================
      -- 5. :BufProfile — profile current buffer performance
      -- ============================================================
      vim.api.nvim_create_user_command("BufProfile", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        local lines = {}
        local function add(...)
          for _, line in ipairs({ ... }) do
            table.insert(lines, line)
          end
        end

        add("═══ Buffer Profile ═══", "")
        add("File: " .. (filepath ~= "" and filepath or "[No Name]"))
        add("Filetype: " .. vim.bo[bufnr].filetype)
        add("Lines: " .. vim.api.nvim_buf_line_count(bufnr))

        -- File size
        if filepath ~= "" then
          local ok, stats = pcall(vim.uv.fs_stat, filepath)
          if ok and stats then
            local size = stats.size
            local size_str
            if size < 1024 then
              size_str = size .. " B"
            elseif size < 1024 * 1024 then
              size_str = string.format("%.1f KB", size / 1024)
            else
              size_str = string.format("%.1f MB", size / (1024 * 1024))
            end
            add("Size: " .. size_str)
          end
        end

        -- LSP clients for this buffer
        local clients = vim.lsp.get_clients({ bufnr = bufnr })
        if #clients > 0 then
          local names = {}
          for _, c in ipairs(clients) do
            table.insert(names, c.name)
          end
          add("LSP: " .. table.concat(names, ", "))
        else
          add("LSP: none")
        end

        -- Treesitter
        local ts_active = pcall(vim.treesitter.get_parser, bufnr)
        add("Treesitter: " .. (ts_active and "active" or "inactive"))

        -- Diagnostics count
        local diags = vim.diagnostic.get(bufnr)
        local counts = { ERROR = 0, WARN = 0, INFO = 0, HINT = 0 }
        for _, d in ipairs(diags) do
          local sev = vim.diagnostic.severity[d.severity]
          if counts[sev] then
            counts[sev] = counts[sev] + 1
          end
        end
        add(string.format("Diagnostics: E:%d W:%d I:%d H:%d", counts.ERROR, counts.WARN, counts.INFO, counts.HINT))

        -- Big file status
        if vim.b[bufnr].bigfile_detected then
          add("⚠ Big file mode: ON (" .. (vim.b[bufnr].bigfile_reason or "unknown") .. ")")
        end

        add("")
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "Show performance profile for current buffer" })

      -- ============================================================
      -- 6. LSP progress indicator in statusline (lualine integration)
      -- ============================================================
      -- Track LSP progress messages for display
      vim.g._lsp_progress_message = ""

      -- Use the built-in LspProgress event (Neovim 0.10+)
      if vim.fn.has("nvim-0.10") == 1 then
        vim.api.nvim_create_autocmd("LspProgress", {
          group = vim.api.nvim_create_augroup("observability_lsp_progress", { clear = true }),
          callback = function(ev)
            local data = ev.data
            if not data or not data.params or not data.params.value then
              return
            end
            local val = data.params.value
            local msg = ""
            if val.kind == "begin" then
              msg = (val.title or "") .. ": " .. (val.message or "starting...")
            elseif val.kind == "report" then
              msg = (val.title or "")
              if val.percentage then
                msg = msg .. string.format(" (%d%%)", val.percentage)
              end
              if val.message then
                msg = msg .. " " .. val.message
              end
            elseif val.kind == "end" then
              msg = ""
            end
            vim.g._lsp_progress_message = msg
            -- Refresh lualine to show progress
            pcall(function()
              require("lualine").refresh()
            end)
            -- Clear after a delay
            if val.kind == "end" then
              vim.defer_fn(function()
                vim.g._lsp_progress_message = ""
                pcall(function()
                  require("lualine").refresh()
                end)
              end, 1000)
            end
          end,
        })
      end

      -- ============================================================
      -- 7. Memory monitoring
      -- ============================================================
      vim.api.nvim_create_user_command("LuaMemory", function()
        collectgarbage("collect")
        local mem = collectgarbage("count")
        vim.notify(string.format("Lua memory usage: %.1f MB (after GC)", mem / 1024), vim.log.levels.INFO)
      end, { desc = "Show Lua memory usage (runs GC first)" })

      -- ============================================================
      -- 8. Keymap for quick access
      -- ============================================================
      vim.keymap.set("n", "<leader>ih", "<cmd>NvimHealth<cr>", { desc = "Neovim health overview" })
      vim.keymap.set("n", "<leader>il", "<cmd>LspStatus<cr>", { desc = "LSP status" })
      vim.keymap.set("n", "<leader>ip", "<cmd>PluginProfile<cr>", { desc = "Plugin load profile" })
      vim.keymap.set("n", "<leader>ib", "<cmd>BufProfile<cr>", { desc = "Buffer profile" })
    end,
  },
}
