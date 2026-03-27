"""Polling/waiting utilities for async DAP operations."""
import time
from typing import Callable, Any, Optional


class TimeoutError(Exception):
    """Raised when a wait condition times out."""
    pass


def wait_for(
    condition: Callable[[], Any],
    timeout: float = 10.0,
    interval: float = 0.3,
    desc: str = "condition",
) -> Any:
    """Wait for a condition to become truthy.
    
    Args:
        condition: Callable that returns a truthy value when satisfied.
        timeout: Max seconds to wait.
        interval: Seconds between polls.
        desc: Description for error message.
    
    Returns:
        The truthy value from condition.
    
    Raises:
        TimeoutError: If condition not met within timeout.
    """
    start = time.time()
    last_err = None
    while time.time() - start < timeout:
        try:
            result = condition()
            if result:
                return result
        except Exception as e:
            last_err = e
        time.sleep(interval)
    
    err_msg = f"Timed out waiting for {desc} after {timeout}s"
    if last_err:
        err_msg += f" (last error: {last_err})"
    raise TimeoutError(err_msg)


def wait_for_nvim_eval(
    nvim,
    lua_expr: str,
    timeout: float = 10.0,
    interval: float = 0.3,
    desc: Optional[str] = None,
) -> Any:
    """Wait for a Lua expression to return truthy in nvim.
    
    Args:
        nvim: pynvim Nvim instance.
        lua_expr: Lua expression to evaluate via luaeval().
        timeout: Max seconds to wait.
        interval: Seconds between polls.
        desc: Description for error message.
    
    Returns:
        The truthy value from evaluation.
    """
    if desc is None:
        desc = f"luaeval({lua_expr!r})"
    
    def check():
        return nvim.eval(f'luaeval("{lua_expr}")')
    
    return wait_for(check, timeout=timeout, interval=interval, desc=desc)
