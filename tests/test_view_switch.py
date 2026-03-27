"""Category F: dap-view view switching tests (P1)."""
import pytest
import time

from utils.nvim_helpers import (
    dap_continue, lua_eval, wait_for_stopped,
)
from utils.wait_helpers import wait_for


def _start_debug_and_stop(nvim):
    """Helper: set breakpoint on line 22, start debug, wait for stop."""
    nvim.command(":22")
    time.sleep(0.3)
    nvim.exec_lua('require("dap").toggle_breakpoint()', [])
    time.sleep(0.5)
    dap_continue(nvim)
    wait_for_stopped(nvim, timeout=20)
    # Open dap-view
    nvim.exec_lua('pcall(function() require("dap-view").open() end)', [])
    time.sleep(1)


def _get_current_view(nvim) -> str:
    """Get current dap-view section name."""
    return lua_eval(nvim, """
        (function()
            local ok, state = pcall(require, 'dap-view.state')
            if ok and state.current_section then
                return state.current_section
            end
            return ""
        end)()
    """) or ""


class TestViewSwitching:
    """Tests for switching between dap-view sections."""

    def test_dap_view_opens(self, dap_session):
        """F9: DapViewToggle opens dap-view window."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        # Check dap-view window exists
        has_win = lua_eval(nvim, """
            (function()
                local ok, state = pcall(require, 'dap-view.state')
                if ok and state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
                    return true
                end
                return false
            end)()
        """)
        assert has_win, "dap-view window should be open"

    def test_switch_to_scopes(self, dap_session):
        """F1: Switch to scopes view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("scopes") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "scopes", f"Expected scopes view, got {view}"

    def test_switch_to_threads(self, dap_session):
        """F2: Switch to threads view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("threads") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "threads", f"Expected threads view, got {view}"

    def test_switch_to_breakpoints(self, dap_session):
        """F4: Switch to breakpoints view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("breakpoints") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "breakpoints", f"Expected breakpoints view, got {view}"

    def test_switch_to_watches(self, dap_session):
        """F3: Switch to watches view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("watches") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "watches", f"Expected watches view, got {view}"

    def test_switch_to_exceptions(self, dap_session):
        """F5: Switch to exceptions view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("exceptions") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "exceptions", f"Expected exceptions view, got {view}"

    def test_switch_to_sessions(self, dap_session):
        """F7: Switch to sessions view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("sessions") end)', [])
        time.sleep(0.5)
        
        view = _get_current_view(nvim)
        assert view == "sessions", f"Expected sessions view, got {view}"

    def test_dap_view_toggle_closes(self, dap_session):
        """F9: DapViewToggle closes when already open."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        # First verify it's open
        has_win = lua_eval(nvim, """
            (function()
                local ok, state = pcall(require, 'dap-view.state')
                if ok and state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
                    return true
                end
                return false
            end)()
        """)
        assert has_win, "dap-view should be open initially"
        
        # Toggle to close
        nvim.exec_lua('pcall(function() require("dap-view").close() end)', [])
        time.sleep(0.5)
        
        has_win_after = lua_eval(nvim, """
            (function()
                local ok, state = pcall(require, 'dap-view.state')
                if ok and state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
                    return true
                end
                return false
            end)()
        """)
        assert not has_win_after, "dap-view should be closed after toggle"

    def test_repl_view(self, dap_session):
        """F6: REPL view can be shown via dap-view."""
        nvim, session_name = dap_session
        
        _start_debug_and_stop(nvim)
        
        # Show REPL via dap-view
        nvim.exec_lua('pcall(function() require("dap-view.repl").show() end)', [])
        time.sleep(0.5)
        
        # Check REPL buffer exists
        has_repl = lua_eval(nvim, """
            (function()
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    local ft = vim.api.nvim_get_option_value('filetype', {buf = buf})
                    if ft == 'dap-repl' then
                        return true
                    end
                end
                return false
            end)()
        """)
        assert has_repl, "REPL buffer should exist"
