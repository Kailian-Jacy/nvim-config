"""Category G: Terminal hide/show behavior tests (P1)."""
import pytest
import subprocess
import os
import time

LAZY_DIR = os.path.expanduser("~/.local/share/nvim/lazy")
DAP_VIEW_PATH = os.path.join(LAZY_DIR, "nvim-dap-view")
DAP_PATH = os.path.join(LAZY_DIR, "nvim-dap")


def _test_terminal_config(hide: str, extra: str = "") -> subprocess.CompletedProcess:
    """Test terminal config validation."""
    lua = (
        f"vim.opt.rtp:append('{DAP_PATH}'); "
        f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
        f"local ok, err = pcall(function() "
        f"require('dap-view').setup({{windows={{terminal={{position='right',width=0.35,hide={hide}{extra}}}}}}}) "
        f"end); "
        f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
    )
    cmd = ["nvim", "--headless", "--clean", "+lua " + lua, "+qa"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    result.output = result.stdout + result.stderr
    return result


class TestTerminalHideConfig:
    """Tests for terminal hide configuration variants (non-overlapping with test_config.py)."""

    def test_hide_codelldb(self):
        """hide={"codelldb"} — valid config."""
        result = _test_terminal_config(hide='{"codelldb"}')
        assert "CONFIG_OK" in result.output

    def test_start_hidden_true(self):
        """G4: start_hidden=true is valid."""
        result = _test_terminal_config(hide='{}', extra=',start_hidden=true')
        assert "CONFIG_OK" in result.output

    def test_start_hidden_false(self):
        """start_hidden=false is valid."""
        result = _test_terminal_config(hide='{}', extra=',start_hidden=false')
        assert "CONFIG_OK" in result.output

    def test_terminal_position_left(self):
        """Terminal position 'left' is valid."""
        lua = (
            f"vim.opt.rtp:append('{DAP_PATH}'); "
            f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
            f"local ok, err = pcall(function() "
            f"require('dap-view').setup({{windows={{terminal={{position='left',width=0.5,hide={{}}}}}}}}) "
            f"end); "
            f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
        )
        cmd = ["nvim", "--headless", "--clean", "+lua " + lua, "+qa"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        assert "CONFIG_OK" in output

    def test_width_various_values(self):
        """Width accepts various numeric values."""
        for width in ["0.25", "0.5", "0.75", "80"]:
            lua = (
                f"vim.opt.rtp:append('{DAP_PATH}'); "
                f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
                f"local ok, err = pcall(function() "
                f"require('dap-view').setup({{windows={{terminal={{position='right',width={width},hide={{}}}}}}}}) "
                f"end); "
                f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
            )
            cmd = ["nvim", "--headless", "--clean", "+lua " + lua, "+qa"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            assert "CONFIG_OK" in output, f"width={width} should be valid"
