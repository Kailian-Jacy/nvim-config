"""Category B: Breakpoint tests (P0)."""
import pytest
import time
import os

from utils.nvim_helpers import (
    dap_set_breakpoint, dap_continue, lua_eval,
    wait_for_stopped, wait_for_dap_session,
)
from utils.wait_helpers import wait_for


class TestBreakpointToggle:
    """Tests for basic breakpoint toggle functionality."""

    def test_toggle_breakpoint_on_line(self, dap_session):
        """B1: Toggle breakpoint places a sign on the line."""
        nvim, session_name = dap_session
        
        # Move to line 22 (x = 10)
        nvim.command(":22")
        time.sleep(0.3)
        
        # Toggle breakpoint
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Check breakpoints are set
        bps = lua_eval(nvim, """
            (function()
                local bps = require('dap.breakpoints').get()
                local count = 0
                for _, buf_bps in pairs(bps) do
                    count = count + #buf_bps
                end
                return count
            end)()
        """)
        assert bps >= 1, f"Expected at least 1 breakpoint, got {bps}"

    def test_toggle_breakpoint_removes(self, dap_session):
        """Toggle breakpoint twice removes it."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        
        # Toggle on
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.3)
        
        # Toggle off
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.3)
        
        # Check breakpoints - line 22 should have none
        bps = lua_eval(nvim, """
            (function()
                local bps = require('dap.breakpoints').get()
                local count = 0
                for bufnr, buf_bps in pairs(bps) do
                    for _, bp in ipairs(buf_bps) do
                        if bp.line == 22 then
                            count = count + 1
                        end
                    end
                end
                return count
            end)()
        """)
        assert bps == 0, f"Expected 0 breakpoints on line 22, got {bps}"

    def test_conditional_breakpoint(self, dap_session):
        """B2: Set conditional breakpoint stores the condition."""
        nvim, session_name = dap_session
        
        nvim.command(":7")
        time.sleep(0.3)
        
        # Set conditional breakpoint
        nvim.exec_lua('require("dap").set_breakpoint("n == 3")', [])
        time.sleep(0.5)
        
        # Check condition is stored
        has_cond = lua_eval(nvim, """
            (function()
                local bps = require('dap.breakpoints').get()
                for _, buf_bps in pairs(bps) do
                    for _, bp in ipairs(buf_bps) do
                        if bp.condition == "n == 3" then
                            return true
                        end
                    end
                end
                return false
            end)()
        """)
        assert has_cond, "Conditional breakpoint not found with correct condition"

    def test_multiple_breakpoints(self, dap_session):
        """Set multiple breakpoints on different lines."""
        nvim, session_name = dap_session
        
        lines = [7, 22, 25]
        for line in lines:
            nvim.command(f":{line}")
            time.sleep(0.2)
            nvim.exec_lua('require("dap").toggle_breakpoint()', [])
            time.sleep(0.3)
        
        bp_count = lua_eval(nvim, """
            (function()
                local bps = require('dap.breakpoints').get()
                local count = 0
                for _, buf_bps in pairs(bps) do
                    count = count + #buf_bps
                end
                return count
            end)()
        """)
        assert bp_count == len(lines), f"Expected {len(lines)} breakpoints, got {bp_count}"


class TestBreakpointHit:
    """Tests for breakpoint hit during debugging."""

    def test_breakpoint_hit_stops_execution(self, dap_session):
        """B3: Breakpoint hit during debug stops the program."""
        nvim, session_name = dap_session
        
        # Set breakpoint on line 22 (x = 10 in main())
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start debugging
        dap_continue(nvim)
        
        # Wait for debugger to stop at breakpoint
        wait_for_stopped(nvim, timeout=20)
        
        # Verify we're stopped
        is_stopped = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                return session and session.stopped_thread_id ~= nil
            end)()
        """)
        assert is_stopped, "Debugger should be stopped at breakpoint"

    def test_clear_all_breakpoints(self, dap_session):
        """B6: Clear all breakpoints removes everything."""
        nvim, session_name = dap_session
        
        # Set multiple breakpoints
        for line in [7, 22, 25]:
            nvim.command(f":{line}")
            time.sleep(0.2)
            nvim.exec_lua('require("dap").toggle_breakpoint()', [])
            time.sleep(0.3)
        
        # Clear all
        nvim.exec_lua("""
            local bps = require('dap.breakpoints')
            local all = bps.get()
            for bufnr, _ in pairs(all) do
                bps.clear(bufnr)
            end
        """, [])
        time.sleep(0.5)
        
        # Verify all cleared
        bp_count = lua_eval(nvim, """
            (function()
                local bps = require('dap.breakpoints').get()
                local count = 0
                for _, buf_bps in pairs(bps) do
                    count = count + #buf_bps
                end
                return count
            end)()
        """)
        assert bp_count == 0, f"Expected 0 breakpoints after clear, got {bp_count}"
