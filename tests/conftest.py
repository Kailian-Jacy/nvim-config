"""Pytest fixtures for nvim-dap testing."""
import pytest
import os
import shutil
import time
import uuid

from utils.nvim_helpers import (
    start_nvim, stop_nvim, setup_dap_plugins, setup_dap_config,
    get_socket_path, FIXTURES_DIR, REPO_DIR,
)
from utils.tmux_helpers import tmux_kill_session


@pytest.fixture
def work_dir(tmp_path):
    """Create a per-test working directory with test fixture."""
    src = os.path.join(FIXTURES_DIR, "test_debug.py")
    dst = os.path.join(str(tmp_path), "test_debug.py")
    shutil.copy2(src, dst)
    return str(tmp_path)


@pytest.fixture
def nvim_session(work_dir):
    """Start nvim in tmux with RPC, load DAP plugins, and yield (nvim, session_name).
    
    Cleans up automatically after test.
    """
    session_id = uuid.uuid4().hex[:8]
    session_name = f"dap-test-{session_id}"
    sock_path = get_socket_path(session_id)
    test_file = os.path.join(work_dir, "test_debug.py")
    
    nvim = start_nvim(session_name, sock_path, file_to_edit=test_file)
    
    # Load DAP plugins
    setup_dap_plugins(nvim)
    
    yield nvim, session_name
    
    # Cleanup
    stop_nvim(session_name, sock_path, nvim)


@pytest.fixture
def dap_session(nvim_session):
    """Start nvim with DAP plugins loaded and configured.
    
    Yields (nvim, session_name).
    """
    nvim, session_name = nvim_session
    setup_dap_config(nvim)
    yield nvim, session_name
