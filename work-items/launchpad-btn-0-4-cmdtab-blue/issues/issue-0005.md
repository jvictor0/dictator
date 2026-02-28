# Issue 0005: Suppress arrow keystroke delivery while next-window hold-cycle is active

- Status: RESOLVED
- Slice-ID: suppress-arrow-keystroke-delivery-while-next-window-hold-cycle-is-active
- Reported by: mayor
- Source: user request

## Problem
When launchpad `0,4` next-window hold-cycle mode is active, arrow keys should drive app cycling only and must not send arrow keystrokes to the foreground app.

## Requested outcome
- While `0,4` hold-cycle session is active, arrow key events are consumed by cycle logic and not forwarded as keystrokes.
- Outside hold-cycle mode, arrow key behavior remains unchanged.
- Scope remains limited to next-window hold-cycle keyboard handling unless SPEC expands scope.
