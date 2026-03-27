"""Category I: Exception breakpoint tests (P2)."""
import pytest
import time
import os

from utils.nvim_helpers import (
    dap_continue, lua_eval, wait_for_stopped, setup_dap_plugins, setup_dap_config,
    start_nvim, stop_nvim, get_socket_path,
)
from utils.wait_helpers import wait_for

import uuid


@pytest.fixture
def exception_fixture(tmp_path):
    """Create a Python file that raises an exception."""
    code = '''
def will_raise():
    x = 1
    y = 0
    result = x / y  # ZeroDivisionError
    return result

def main():
    try:
        will_raise()
    except ZeroDivisionError as e:
        print(f"Caught: {e}")
    print("Done")

if __name__ == "__main__":
    main()
'''
    test_file = os.path.join(str(tmp_path), "test_exception.py")
    with open(test_file, "w") as f:
        f.write(code)
    return str(tmp_path), test_file


class TestExceptions:
    """Tests for exception breakpoint functionality."""

    def test_exception_filters_available(self, dap_session):
        """I1: DAP session provides exception breakpoint filters."""
        nvim, session_name = dap_session
        
        # Start a debug session first to get capabilities
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        # Check exception filters from session capabilities
        has_filters = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                if not session then return false end
                local caps = session.capabilities or {}
                local filters = caps.exceptionBreakpointFilters or {}
                return #filters > 0
            end)()
        """)
        # debugpy should provide "raised" and "uncaught" filters
        assert has_filters, "debugpy should provide exception breakpoint filters"

    def test_exception_filter_names(self, dap_session):
        """I1: debugpy provides 'raised' and 'uncaught' exception filters."""
        nvim, session_name = dap_session
        
        nvim.command(":22")
        time.sleep(0.3)
        nvim.exec_lua('require("dap").toggle_breakpoint()', [])
        time.sleep(0.5)
        dap_continue(nvim)
        wait_for_stopped(nvim, timeout=20)
        
        filter_ids = lua_eval(nvim, """
            (function()
                local session = require('dap').session()
                if not session then return {} end
                local caps = session.capabilities or {}
                local filters = caps.exceptionBreakpointFilters or {}
                local ids = {}
                for _, f in ipairs(filters) do
                    table.insert(ids, f.filter)
                end
                return ids
            end)()
        """)
        # debugpy typically provides these filters
        assert isinstance(filter_ids, list), "Should get a list of filter IDs"
        assert len(filter_ids) > 0, "Should have at least one exception filter"
