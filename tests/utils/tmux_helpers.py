"""Tmux session management helpers for nvim testing."""
import subprocess
import time
import os
from typing import Optional


def tmux_run(args: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a tmux command."""
    cmd = ["tmux"] + args
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def tmux_has_session(session_name: str) -> bool:
    """Check if a tmux session exists."""
    result = tmux_run(["has-session", "-t", session_name], check=False)
    return result.returncode == 0


def tmux_kill_session(session_name: str) -> None:
    """Kill a tmux session if it exists."""
    if tmux_has_session(session_name):
        tmux_run(["kill-session", "-t", session_name], check=False)


def tmux_new_session(
    session_name: str,
    command: str,
    width: int = 200,
    height: int = 50,
) -> None:
    """Create a new tmux session running a command."""
    tmux_kill_session(session_name)
    tmux_run([
        "new-session", "-d",
        "-s", session_name,
        "-x", str(width),
        "-y", str(height),
        command,
    ])


def tmux_capture_pane(session_name: str) -> str:
    """Capture the contents of a tmux pane."""
    result = tmux_run(["capture-pane", "-t", session_name, "-p"], check=False)
    return result.stdout


def tmux_send_keys(session_name: str, keys: str, enter: bool = False) -> None:
    """Send keys to a tmux session."""
    tmux_run(["send-keys", "-t", session_name, keys])
    if enter:
        tmux_run(["send-keys", "-t", session_name, "Enter"])


def assert_screen_contains(
    session_name: str,
    text: str,
    timeout: float = 5.0,
    interval: float = 0.3,
) -> str:
    """Assert that tmux pane contains specific text, with retries."""
    start = time.time()
    while time.time() - start < timeout:
        screen = tmux_capture_pane(session_name)
        if text in screen:
            return screen
        time.sleep(interval)
    screen = tmux_capture_pane(session_name)
    assert text in screen, f"Expected '{text}' in tmux pane. Got:\n{screen}"
    return screen


def assert_screen_not_contains(
    session_name: str,
    text: str,
    timeout: float = 2.0,
    interval: float = 0.3,
) -> str:
    """Assert that tmux pane does NOT contain specific text."""
    # Wait briefly then check
    time.sleep(timeout)
    screen = tmux_capture_pane(session_name)
    assert text not in screen, f"Unexpected '{text}' found in tmux pane. Got:\n{screen}"
    return screen
