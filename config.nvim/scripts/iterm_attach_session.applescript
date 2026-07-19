-- iterm_attach_session.applescript
--
-- Usage:
--   osascript iterm_attach_session.applescript "<shell command>" "<session>"
--
-- Opens a new iTerm2 tab in the current window (or a fresh window if iTerm is
-- running with none open), runs the given command, and marks the tab's session
-- with the tmux session name in the iTerm2 user variable `user.nvim_session`.
-- That mark is what the <D-a> path queries in real time to find/focus this tab,
-- and it goes away by itself when the tab is closed.
--
-- Used by the Neovim floatterm <D-A> handoff to reattach a tmux session (that
-- was just detached from Neovim) in a native iTerm2 tab. The command is
-- assembled by `config.floatterm.tmux.attach_cmd_string`, so it is an ordinary
-- `tmux -S <socket> new-session -As <session> …` invocation.
on run argv
    if (count of argv) < 2 then
        error "usage: osascript iterm_attach_session.applescript <command> <session>"
    end if
    set theCommand to item 1 of argv
    set theSession to item 2 of argv
    tell application "iTerm"
        if (count of windows) > 0 then
            -- Existing window: add a new tab (it becomes the current tab).
            tell current window
                create tab with default profile
            end tell
        else
            -- No window: create one ourselves. (Activating iTerm here is
            -- unreliable for opening a window, so don't depend on it.)
            create window with default profile
        end if
        -- A window now exists, so activating just brings iTerm forward.
        activate
        -- The target session is the current window's current session.
        tell current session of current window
            set variable named "user.nvim_session" to theSession
            write text theCommand
        end tell
    end tell
end run
