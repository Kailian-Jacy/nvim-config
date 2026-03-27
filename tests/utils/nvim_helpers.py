"""Neovim RPC helper functions for testing."""
import pynvim
import time
import os
import subprocess
from typing import Any, Optional

from .tmux_helpers import tmux_new_session, tmux_kill_session, tmux_capture_pane
from .wait_helpers import wait_for


# Paths to lazy plugins
LAZY_DIR = os.path.expanduser("~/.local/share/nvim/lazy")
DAP_VIEW_PATH = os.path.join(LAZY_DIR, "nvim-dap-view")
DAP_PATH = os.path.join(LAZY_DIR, "nvim-dap")
DAP_VIRTUAL_TEXT_PATH = os.path.join(LAZY_DIR, "nvim-dap-virtual-text")
DAP_PYTHON_PATH = os.path.join(LAZY_DIR, "nvim-dap-python")
PERSISTENT_BP_PATH = os.path.join(LAZY_DIR, "persistent-breakpoints.nvim")
LUALINE_PATH = os.path.join(LAZY_DIR, "lualine.nvim")

# Repo paths
REPO_DIR = os.path.expanduser("~/.openclaw/workspace/nvim-refine")
FIXTURES_DIR = os.path.join(REPO_DIR, "tests", "fixtures")


def get_socket_path(session_id: str) -> str:
    """Get a unique socket path for a test session."""
    return f"/tmp/nvim-dap-test-{session_id}.sock"


def cleanup_socket(sock_path: str) -> None:
    """Remove a stale socket file."""
    if os.path.exists(sock_path):
        os.unlink(sock_path)


def start_nvim(
    session_name: str,
    sock_path: str,
    file_to_edit: Optional[str] = None,
    width: int = 200,
    height: int = 50,
    extra_args: str = "",
    wait: float = 3.0,
) -> pynvim.Nvim:
    """Start nvim in a tmux session with RPC socket and connect.
    
    Args:
        session_name: Tmux session name.
        sock_path: Socket path for pynvim RPC.
        file_to_edit: Optional file to open.
        width: Tmux window width.
        height: Tmux window height.
        extra_args: Additional nvim command-line arguments.
        wait: Seconds to wait for nvim to start.
    
    Returns:
        Connected pynvim.Nvim instance.
    """
    cleanup_socket(sock_path)
    
    cmd_parts = [f"nvim --listen {sock_path}"]
    if extra_args:
        cmd_parts.append(extra_args)
    if file_to_edit:
        cmd_parts.append(file_to_edit)
    
    cmd = " ".join(cmd_parts)
    tmux_new_session(session_name, cmd, width=width, height=height)
    
    # Wait for nvim to start and socket to appear
    def socket_ready():
        return os.path.exists(sock_path)
    
    wait_for(socket_ready, timeout=wait + 5, interval=0.3, desc="nvim socket")
    time.sleep(0.5)  # Extra settle time
    
    nvim = pynvim.attach("socket", path=sock_path)
    return nvim


def stop_nvim(session_name: str, sock_path: str, nvim: Optional[pynvim.Nvim] = None) -> None:
    """Stop nvim and cleanup."""
    if nvim:
        try:
            nvim.command("qa!")
        except Exception:
            pass
    
    time.sleep(0.3)
    tmux_kill_session(session_name)
    cleanup_socket(sock_path)


def setup_dap_plugins(nvim: pynvim.Nvim) -> None:
    """Load DAP-related plugins into nvim runtime path."""
    plugin_paths = [
        DAP_PATH,
        DAP_VIEW_PATH, 
        DAP_VIRTUAL_TEXT_PATH,
        DAP_PYTHON_PATH,
        PERSISTENT_BP_PATH,
        LUALINE_PATH,
    ]
    for path in plugin_paths:
        if os.path.isdir(path):
            nvim.command(f"set rtp+={path}")


def setup_dap_config(nvim: pynvim.Nvim, hide: str = "{}", width: str = "0.35") -> None:
    """Setup dap-view with the specified config.
    
    Args:
        nvim: pynvim.Nvim instance.
        hide: Lua table expression for hide config (e.g., '{}', '{"debugpy"}').
        width: Width value as string.
    """
    lua = f"""
    local dap = require('dap')
    
    -- Register debugpy adapter
    dap.adapters.debugpy = {{
        type = "executable",
        command = "python3",
        args = {{ "-m", "debugpy.adapter" }},
        name = "debugpy",
    }}
    
    -- Default Python configuration
    dap.configurations.python = {{
        {{
            type = "debugpy",
            request = "launch",
            name = "Launch file",
            program = "${{file}}",
            pythonPath = function()
                return "python3"
            end,
        }},
    }}
    
    -- Configure dap-view
    require('dap-view').setup({{
        winbar = {{
            show = true,
            sections = {{ "repl", "console", "watches", "scopes", "exceptions", "breakpoints", "threads", "sessions" }},
            default_section = "scopes",
        }},
        windows = {{
            terminal = {{
                position = "right",
                width = {width},
                hide = {hide},
            }},
        }},
        switchbuf = "uselast",
    }})
    
    -- Setup signs
    vim.fn.sign_define("DapBreakpoint", {{ text = "●", texthl = "DapBreakpoint" }})
    vim.fn.sign_define("DapBreakpointCondition", {{ text = "◆", texthl = "DapBreakpointCondition" }})
    vim.fn.sign_define("DapStopped", {{ text = "▶", texthl = "DapStopped", linehl = "debugPc" }})
    """
    nvim.exec_lua(lua, [])


def lua_eval(nvim: pynvim.Nvim, expr: str) -> Any:
    """Evaluate a Lua expression and return result."""
    return nvim.exec_lua(f"return {expr}", [])


def dap_set_breakpoint(nvim: pynvim.Nvim, line: int, condition: Optional[str] = None) -> None:
    """Set a DAP breakpoint at the specified line."""
    nvim.command(f":{line}")
    if condition:
        nvim.exec_lua(f'require("dap").set_breakpoint("{condition}")', [])
    else:
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])


def dap_continue(nvim: pynvim.Nvim) -> None:
    """Start or continue debugging.
    
    For first launch, uses dap.run() directly with config to avoid any interactive prompt.
    For subsequent continues, uses dap.continue().
    """
    has_session = get_dap_session(nvim)
    if has_session:
        nvim.exec_lua('require("dap").continue()', [])
    else:
        # Run directly with config to avoid interactive config picker
        nvim.exec_lua("""
            local dap = require('dap')
            local configs = dap.configurations.python
            if configs and #configs > 0 then
                dap.run(configs[1])
            else
                dap.continue()
            end
        """, [])


def dap_step_over(nvim: pynvim.Nvim) -> None:
    """Step over."""
    nvim.exec_lua('require("dap").step_over()', [])


def dap_step_into(nvim: pynvim.Nvim) -> None:
    """Step into."""
    nvim.exec_lua('require("dap").step_into()', [])


def dap_step_out(nvim: pynvim.Nvim) -> None:
    """Step out."""
    nvim.exec_lua('require("dap").step_out()', [])


def dap_terminate(nvim: pynvim.Nvim) -> None:
    """Terminate debug session."""
    nvim.exec_lua('require("dap").terminate()', [])


def dap_run_last(nvim: pynvim.Nvim) -> None:
    """Run last debug configuration."""
    nvim.exec_lua('require("dap").run_last()', [])


def dap_disconnect(nvim: pynvim.Nvim) -> None:
    """Disconnect from debug session."""
    nvim.exec_lua('require("dap").disconnect()', [])


def get_dap_session(nvim: pynvim.Nvim) -> Any:
    """Check if there's an active DAP session."""
    return lua_eval(nvim, 'require("dap").session() ~= nil')


def wait_for_dap_session(nvim: pynvim.Nvim, timeout: float = 15.0) -> None:
    """Wait for DAP session to be established."""
    wait_for(
        lambda: get_dap_session(nvim),
        timeout=timeout,
        interval=0.5,
        desc="DAP session active",
    )


def wait_for_stopped(nvim: pynvim.Nvim, timeout: float = 15.0) -> None:
    """Wait for debugger to stop (hit breakpoint/step)."""
    def check():
        return lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                return session and session.stopped_thread_id ~= nil
            end)()
        """)
    
    wait_for(check, timeout=timeout, interval=0.5, desc="debugger stopped")


def wait_for_no_session(nvim: pynvim.Nvim, timeout: float = 10.0) -> None:
    """Wait for DAP session to end."""
    def check():
        return not get_dap_session(nvim)
    
    wait_for(check, timeout=timeout, interval=0.5, desc="no DAP session")


def get_signs(nvim: pynvim.Nvim, group: str = "") -> list:
    """Get signs placed in the current buffer."""
    buf = nvim.current.buffer.number
    if group:
        return nvim.exec_lua(f'return vim.fn.sign_getplaced({buf}, {{group="{group}"}})', [])
    return nvim.exec_lua(f'return vim.fn.sign_getplaced({buf})', [])


def get_current_line(nvim: pynvim.Nvim) -> int:
    """Get the current cursor line number."""
    return nvim.eval('line(".")')
