"""Category J: Disconnect/reconnect tests (P2)."""
import pytest
import time

from utils.nvim_helpers import (
    dap_continue, dap_disconnect, dap_terminate, lua_eval,
    wait_for_stopped, wait_for_no_session, get_dap_session,
)
from utils.wait_helpers import wait_for


class TestDisconnect:
    """Tests for debug session disconnect."""

    def test_disconnect_ends_session(self, dap_session):
        """J1: Disconnect from debug session ends it cleanly."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Disconnect
        dap_disconnect(nvim)
        
        # Wait for session to end
        wait_for_no_session(nvim, timeout=10)
        
        has_session = get_dap_session(nvim)
        assert not has_session, "Session should be ended after disconnect"

    def test_terminate_is_clean(self, dap_session):
        """J5-related: Terminate handles cleanup gracefully."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Terminate
        dap_terminate(nvim)
        wait_for_no_session(nvim, timeout=10)
        
        # Verify nvim is still responsive
        result = nvim.eval("1 + 1")
        assert result == 2, "nvim should still be responsive after terminate"

    def test_can_start_new_session_after_disconnect(self, dap_session):
        """After disconnect, a new session can be started."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Disconnect
        dap_disconnect(nvim)
        wait_for_no_session(nvim, timeout=10)
        
        # Start new session
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        is_stopped = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                return s and s.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Should be stopped in new session"
