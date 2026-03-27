"""Category E: Debug control flow tests (P0)."""
import pytest
import time

from utils.nvim_helpers import (
    dap_continue, dap_step_over, dap_step_into, dap_step_out,
    dap_terminate, dap_run_last, lua_eval,
    wait_for_stopped, wait_for_no_session, wait_for_dap_session,
    get_dap_session,
)
from utils.wait_helpers import wait_for


class TestContinue:
    """Tests for continue/resume."""

    def test_continue_runs_to_next_breakpoint(self, dap_session):
        """E1: Continue runs to the next breakpoint."""
        nvim, session_name = dap_session
        
        # Set two breakpoints
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.3)
        
        nvim.command(":25")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start debugging - should stop at first BP (line 22)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Continue - should stop at second BP (line 25)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=10)
        
        # Verify we're still stopped (at second breakpoint)
        is_stopped = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                return s and s.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Should be stopped at second breakpoint"


class TestStepping:
    """Tests for step over/into/out."""

    def test_step_over(self, dap_session):
        """E2: Step over moves to next line in same frame."""
        nvim, session_name = dap_session
        
        # Set breakpoint on line 22 (x = 10)
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start and wait for stop
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Step over
        dap_step_over(nvim)
        wait_for_stopped(nvim, timeout=10)
        
        # Should still be in a stopped state (next line)
        is_stopped = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                return s and s.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Should be stopped after step over"

    def test_step_into(self, dap_session):
        """E3: Step into enters a function call."""
        nvim, session_name = dap_session
        
        # Set breakpoint on line 23 (y = factorial(5))
        nvim.command(":23")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start and wait for stop
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Step into factorial
        dap_step_into(nvim)
        wait_for_stopped(nvim, timeout=10)
        
        # Check that we're inside factorial function (should be in a different frame)
        frame_name = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                if s and s.current_frame then
                    return s.current_frame.name or ""
                end
                return ""
            end)()
        """)
        assert frame_name != "", "Should have a current frame after step into"

    def test_step_out(self, dap_session):
        """E4: Step out returns to caller frame."""
        nvim, session_name = dap_session
        
        # Set breakpoint inside factorial (line 9)
        nvim.command(":9")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start and wait for stop
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Step out
        dap_step_out(nvim)
        wait_for_stopped(nvim, timeout=10)
        
        is_stopped = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                return s and s.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Should be stopped after step out"


class TestTerminate:
    """Tests for session termination."""

    def test_terminate_ends_session(self, dap_session):
        """E5: Terminate ends the debug session."""
        nvim, session_name = dap_session
        
        # Set breakpoint and start
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Terminate
        dap_terminate(nvim)
        
        # Wait for session to end
        wait_for_no_session(nvim, timeout=10)
        
        has_session = get_dap_session(nvim)
        assert not has_session, "Session should be terminated"

    def test_run_last_after_terminate(self, dap_session):
        """E7: Run last re-launches with same config after session ends."""
        nvim, session_name = dap_session
        
        # Set breakpoint and start
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Terminate
        dap_terminate(nvim)
        wait_for_no_session(nvim, timeout=10)
        
        # Run last
        dap_run_last(nvim)
        
        # Should stop at same breakpoint again
        wait_for_stopped(nvim, timeout=20)
        
        is_stopped = lua_eval(nvim, """
            (function()
                local s = require('dap').session()
                return s and s.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Should be stopped again after run_last"
