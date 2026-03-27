"""Category A: Configuration validation tests (P0)."""
import pytest
import subprocess
import re
import os

LAZY_DIR = os.path.expanduser("~/.local/share/nvim/lazy")
DAP_VIEW_PATH = os.path.join(LAZY_DIR, "nvim-dap-view")
DAP_PATH = os.path.join(LAZY_DIR, "nvim-dap")
REPO_DIR = os.path.expanduser("~/.openclaw/workspace/nvim-refine")
DEBUG_LUA = os.path.join(REPO_DIR, "config.nvim", "lua", "plugins", "debug.lua")


def _run_nvim_lua(lua_code: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Run a Lua snippet in headless nvim and return the result.
    
    Note: nvim --headless prints to stderr, so we merge stdout+stderr for checking.
    """
    cmd = [
        "nvim", "--headless", "--clean",
        "+lua " + lua_code,
        "+qa",
    ]
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout
    )
    # Combine stdout and stderr for assertion - nvim headless uses stderr for print()
    result.output = result.stdout + result.stderr
    return result


def _test_dap_view_config(hide: str, width_field: str = "width", width_val: str = "0.35") -> subprocess.CompletedProcess:
    """Test dap-view setup with given config, return process result."""
    lua = (
        f"vim.opt.rtp:append('{DAP_PATH}'); "
        f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
        f"local ok, err = pcall(function() "
        f"require('dap-view').setup({{windows={{terminal={{position='right',{width_field}={width_val},hide={hide}}}}}}}) "
        f"end); "
        f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
    )
    return _run_nvim_lua(lua)


class TestFixedConfig:
    """Tests that the fixed configuration loads correctly."""

    def test_hide_empty_table_loads_ok(self):
        """A1: hide={} (fixed config) loads without error."""
        result = _test_dap_view_config(hide="{}")
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_width_field_loads_ok(self):
        """A2: width=0.35 (fixed config) loads without error."""
        result = _test_dap_view_config(hide="{}", width_field="width", width_val="0.35")
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_hide_with_adapter_name_loads_ok(self):
        """hide={"debugpy"} also loads correctly."""
        result = _test_dap_view_config(hide='{"debugpy"}')
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_hide_with_multiple_adapters_loads_ok(self):
        """hide={"debugpy","codelldb"} also loads correctly."""
        result = _test_dap_view_config(hide='{"debugpy","codelldb"}')
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"


class TestOldBrokenConfig:
    """Tests that the old broken configuration triggers correct errors."""

    def test_hide_boolean_triggers_error(self):
        """A3: hide=true (old config) triggers 'expected table, got boolean'."""
        result = _test_dap_view_config(hide="true")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"
        assert "expected table, got boolean" in result.output or "hide" in result.output

    def test_size_field_triggers_error(self):
        """A4: size=0.35 (old config) triggers 'unexpected field'."""
        result = _test_dap_view_config(hide="{}", width_field="size", width_val="0.35")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"
        assert "unexpected field" in result.output or "size" in result.output

    def test_both_old_bugs_together(self):
        """Both size and hide=true together trigger an error."""
        result = _test_dap_view_config(hide="true", width_field="size", width_val="0.35")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"


class TestConfigEdgeCases:
    """Edge cases for configuration validation."""

    def test_hide_string_triggers_error(self):
        """hide='debugpy' (string, not table) triggers error."""
        result = _test_dap_view_config(hide="'debugpy'")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"

    def test_hide_number_triggers_error(self):
        """hide=1 (number) triggers error."""
        result = _test_dap_view_config(hide="1")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"

    def test_default_config_loads_ok(self):
        """Default config (no overrides) loads fine."""
        lua = (
            f"vim.opt.rtp:append('{DAP_PATH}'); "
            f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
            f"local ok, err = pcall(function() "
            f"require('dap-view').setup() "
            f"end); "
            f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
        )
        result = _run_nvim_lua(lua)
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"


class TestRealDebugLua:
    """Regression tests against the real config.nvim/lua/plugins/debug.lua file.
    
    These tests parse the actual debug.lua to verify the fix hasn't regressed.
    If someone changes hide={} back to hide=true or width back to size,
    these tests WILL fail.
    """

    def _read_debug_lua(self) -> str:
        """Read the real debug.lua file content."""
        with open(DEBUG_LUA, "r") as f:
            return f.read()

    def _extract_terminal_block(self, content: str) -> str:
        """Extract the windows.terminal config block from debug.lua."""
        # Find the terminal = { ... } block inside the dap-view setup call
        # Look for the terminal block between 'terminal = {' and its closing '}'
        match = re.search(
            r'windows\s*=\s*\{[^}]*terminal\s*=\s*\{(.*?)\}',
            content,
            re.DOTALL,
        )
        assert match, "Could not find windows.terminal block in debug.lua"
        return match.group(1)

    def test_real_debug_lua_hide_is_table(self):
        """REGRESSION: debug.lua hide field must be a Lua table, not a boolean."""
        content = self._read_debug_lua()
        terminal_block = self._extract_terminal_block(content)

        # Must NOT contain 'hide = true' or 'hide = false'
        assert not re.search(r'hide\s*=\s*true', terminal_block), \
            "REGRESSION: hide is set to boolean 'true' — must be a table like {} or {\"debugpy\"}"
        assert not re.search(r'hide\s*=\s*false', terminal_block), \
            "REGRESSION: hide is set to boolean 'false' — must be a table like {} or {\"debugpy\"}"

        # Must contain 'hide = {' (table form)
        assert re.search(r'hide\s*=\s*\{', terminal_block), \
            "REGRESSION: hide must be a table (e.g. {} or {\"debugpy\"}), not found"

    def test_real_debug_lua_uses_width_not_size(self):
        """REGRESSION: debug.lua terminal must use 'width', not 'size'."""
        content = self._read_debug_lua()
        terminal_block = self._extract_terminal_block(content)

        # Must NOT contain 'size ='
        assert not re.search(r'\bsize\s*=', terminal_block), \
            "REGRESSION: terminal config uses 'size' — must use 'width'"

        # Must contain 'width ='
        assert re.search(r'\bwidth\s*=', terminal_block), \
            "REGRESSION: terminal config must have 'width' field"

    def test_real_debug_lua_dap_view_setup_succeeds(self):
        """REGRESSION: The actual dap-view config from debug.lua loads without error.
        
        Extracts the dap-view.setup() call from debug.lua and runs it in headless nvim.
        """
        content = self._read_debug_lua()

        # Extract the full setup call: require("dap-view").setup({...})
        # Find it by locating the setup block
        match = re.search(
            r'require\("dap-view"\)\.setup\((\{.*?\})\)\s*$',
            content,
            re.DOTALL | re.MULTILINE,
        )
        assert match, "Could not find dap-view.setup() call in debug.lua"
        setup_arg = match.group(1)

        # Replace any require() calls in the config with stubs to avoid
        # needing the full plugin ecosystem
        # The base_sections contain action functions with require("dap-view.views")
        # which will be available since we add dap-view to rtp
        lua = (
            f"vim.opt.rtp:append('{DAP_PATH}'); "
            f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
            f"local ok, err = pcall(function() "
            f"require('dap-view').setup({setup_arg}) "
            f"end); "
            f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
        )
        result = _run_nvim_lua(lua)
        assert "CONFIG_OK" in result.output, \
            f"REGRESSION: Real debug.lua dap-view config fails to load: {result.output}"
