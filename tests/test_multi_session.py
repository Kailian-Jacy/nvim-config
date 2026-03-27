"""Category H: Multi-session tests (P2)."""
import pytest
import time

from utils.nvim_helpers import (
    dap_continue, dap_terminate, lua_eval,
    wait_for_stopped, wait_for_no_session,
)
from utils.wait_helpers import wait_for


class TestMultiSession:
    """Tests for multiple debug session scenarios."""

    def test_session_count_single(self, dap_session):
        """H1-pre: Single session shows in sessions list."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        session_count = lua_eval(nvim, """
            (function()
                local sessions = require('dap').sessions()
                local count = 0
                for _ in pairs(sessions) do count = count + 1 end
                return count
            end)()
        """)
        assert session_count >= 1, f"Expected at least 1 session, got {session_count}"

    def test_sessions_api_returns_table(self, dap_session):
        """H4: dap.sessions() returns a proper table."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        is_table = lua_eval(nvim, """
            (function()
                local sessions = require('dap').sessions()
                return type(sessions) == "table"
            end)()
        """)
        assert is_table, "dap.sessions() should return a table"

    def test_terminated_session_removed(self, dap_session):
        """After terminating, session count goes to 0."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        dap_terminate(nvim)
        wait_for_no_session(nvim, timeout=10)
        
        session_count = lua_eval(nvim, """
            (function()
                local sessions = require('dap').sessions()
                local count = 0
                for _ in pairs(sessions) do count = count + 1 end
                return count
            end)()
        """)
        assert session_count == 0, f"Expected 0 sessions after terminate, got {session_count}"
