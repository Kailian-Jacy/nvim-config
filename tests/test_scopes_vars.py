"""Category D: Stack frames, variables, REPL tests (P0)."""
import pytest
import time

from utils.nvim_helpers import (
    dap_set_breakpoint, dap_continue, lua_eval,
    wait_for_stopped, wait_for_dap_session,
)
from utils.tmux_helpers import assert_screen_contains, tmux_capture_pane
from utils.wait_helpers import wait_for


class TestScopes:
    """Tests for scopes/variables display."""

    def test_scopes_show_variables_after_stop(self, dap_session):
        """D3: After stopping, scopes view shows local variables."""
        nvim, session_name = dap_session
        
        # Set breakpoint on line 24 (z = x + y, after x and y are assigned)
        nvim.command(":24")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start debugging
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Open dap-view and switch to scopes
        nvim.exec_lua('pcall(function() require("dap-view").open() end)', [])
        time.sleep(1)
        nvim.exec_lua('pcall(function() require("dap-view.views").switch_to_view("scopes") end)', [])
        time.sleep(1)
        
        # Check that scopes have data
        has_scopes = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                if not session or not session.current_frame then return false end
                return session.current_frame.scopes ~= nil and #session.current_frame.scopes > 0
            end)()
        """)
        assert has_scopes, "Debug session should have scopes with variables"

    def test_session_has_current_frame(self, dap_session):
        """D1: After stopping, session has current_frame with stack info."""
        nvim, session_name = dap_session
        
        # Set breakpoint inside factorial function (line 9: result = n * ...)
        nvim.command(":9")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start debugging
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Check current frame exists
        has_frame = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                return session and session.current_frame ~= nil
            end)()
        """)
        assert has_frame, "Session should have current_frame after stopping"

    def test_stack_frames_exist(self, dap_session):
        """D1: Stack frames are visible after stopping in nested function."""
        nvim, session_name = dap_session
        
        # Set breakpoint inside factorial (line 9)
        nvim.command(":9")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        
        # Start debugging
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Check threads/stack frames
        frame_count = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                if not session then return 0 end
                local threads = session.threads
                if not threads then return 0 end
                for _, thread in pairs(threads) do
                    if thread.frames then
                        return #thread.frames
                    end
                end
                return 0
            end)()
        """)
        # Should have at least 2 frames: factorial + main
        assert frame_count >= 2, f"Expected >= 2 stack frames, got {frame_count}"


class TestREPL:
    """Tests for DAP REPL functionality."""

    def test_repl_toggle(self, dap_session):
        """D5: DAP REPL can be opened."""
        nvim, session_name = dap_session
        
        # Set breakpoint and run
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Toggle REPL
        nvim.exec_lua('require("dap").repl.toggle()', [])
        time.sleep(1)
        
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
        assert has_repl, "REPL buffer should exist after toggle"
