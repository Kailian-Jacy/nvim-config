"""Category C: launch.json tests (P1)."""
import pytest
import json
import os
import re
import time

from utils.nvim_helpers import lua_eval, REPO_DIR

DEBUG_LUA = os.path.join(REPO_DIR, "config.nvim", "lua", "plugins", "debug.lua")


class TestLaunchJsonTemplate:
    """Tests for DapConfigTemplate command logic."""

    def test_debug_lua_has_python_template(self):
        """C1: debug.lua defines a Python launch.json template with debugpy."""
        with open(DEBUG_LUA, "r") as f:
            content = f.read()

        # Verify the template section exists and contains python/debugpy
        assert "DapConfigTemplate" in content, "debug.lua should define DapConfigTemplate command"
        assert re.search(r'python\s*=\s*\[\[', content), \
            "debug.lua should have a python template string"
        assert '"debugpy"' in content, "Python template should reference debugpy adapter"

    def test_auto_detect_logic_in_debug_lua(self):
        """C2: debug.lua auto-detect logic checks for .py files and pyproject.toml."""
        with open(DEBUG_LUA, "r") as f:
            content = f.read()

        # Verify the auto-detection patterns exist in the code
        assert "*.py" in content or "setup.py" in content or "pyproject.toml" in content, \
            "debug.lua should check for Python project markers"
        assert "go.mod" in content, \
            "debug.lua should check for Go project markers"
        assert "Cargo.toml" in content, \
            "debug.lua should check for Rust project markers"
        # Verify auto-detect assigns project_type
        assert re.search(r'project_type\s*=\s*"python"', content), \
            "debug.lua should set project_type='python' for Python projects"

    def test_launch_json_read_configurations(self, dap_session):
        """C3: nvim-dap reads existing launch.json configurations."""
        nvim, session_name = dap_session

        cwd = nvim.eval('getcwd()')
        vscode_dir = os.path.join(cwd, ".vscode")
        os.makedirs(vscode_dir, exist_ok=True)

        # Create a launch.json
        launch_config = {
            "version": "0.2.0",
            "configurations": [
                {
                    "type": "debugpy",
                    "request": "launch",
                    "name": "Test Config",
                    "program": "${file}",
                }
            ]
        }

        with open(os.path.join(vscode_dir, "launch.json"), "w") as f:
            json.dump(launch_config, f)

        # Try loading with ext-vscode
        has_ext = lua_eval(nvim, """
            (function()
                local ok = pcall(require, 'dap.ext.vscode')
                return ok
            end)()
        """)

        if not has_ext:
            pytest.skip("dap.ext.vscode not available")

        nvim.exec_lua("""
            require('dap.ext.vscode').load_launchjs(nil, {debugpy = {"python"}})
        """, [])
        time.sleep(0.5)

        configs = lua_eval(nvim, """
            (function()
                local configs = require('dap').configurations.python or {}
                return #configs
            end)()
        """)
        assert configs >= 1, "Should have loaded at least 1 configuration from launch.json"
