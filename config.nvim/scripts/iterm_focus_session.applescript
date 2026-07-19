-- iterm_focus_session.applescript
--
-- Usage:
--   osascript iterm_focus_session.applescript "<session>"
--
-- Searches running iTerm2 windows/tabs/sessions in real time for the session
-- marked with `user.nvim_session` == <session> (the mark set by
-- iterm_attach_session.applescript at hand-off time). If found, brings iTerm2
-- to the front, selects that window/tab/session, and prints "focused".
-- Otherwise prints "not-found". Because the mark lives on the iTerm2 tab, a
-- closed tab is simply not found here — no stale state to release.
--
-- iTerm2 is never launched by this script: if it is not running (or not
-- installed) we return "not-found" so the caller can fall back to opening the
-- in-editor floatterm as usual.
on run argv
    if (count of argv) < 1 then
        error "usage: osascript iterm_focus_session.applescript <session>"
    end if
    set theSession to item 1 of argv

    -- `is running` does NOT launch the app; if iTerm2 is not installed this
    -- errors out and osascript exits non-zero, which the caller treats as a
    -- fall-through to the normal floatterm.
    if not (application "iTerm" is running) then
        return "not-found"
    end if

    tell application "iTerm"
        repeat with w in windows
            repeat with t in tabs of w
                repeat with s in sessions of t
                    set sVar to ""
                    try
                        -- `variable named` is a command sent to the session,
                        -- so it must run inside a `tell s` block (the
                        -- `... of s` form does not route correctly).
                        tell s to set sVar to (variable named "user.nvim_session")
                    end try
                    if sVar is equal to theSession then
                        select w
                        select t
                        select s
                        activate
                        return "focused"
                    end if
                end repeat
            end repeat
        end repeat
    end tell
    return "not-found"
end run
