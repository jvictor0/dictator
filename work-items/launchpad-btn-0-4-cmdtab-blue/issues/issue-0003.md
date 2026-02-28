# Issue 0003: Replace Command+Tab mapping with immediate native next-window switch

- Status: RESOLVED
- Slice-ID: replace-command-tab-mapping-with-immediate-native-next-window-switch
- Reported by: mayor
- Source: user request

## Problem
Pressing the mapped launchpad button currently sends `Command+Tab`. This is not useful for one-button behavior because macOS only commits the app switch after the `Command` key is released.

## Requested outcome
- Do not send `Command+Tab` for this button mapping.
- Use the Apple-native interface for direct next-window selection that switches immediately on button press.
- Preserve one-button behavior (single press, no modifier hold/release dependency).

## Notes
- Treat this as functionally equivalent user intent to `Command+Tab`, but with immediate activation semantics.
- Keep scope focused on this button behavior unless SPEC expands scope.
