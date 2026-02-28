# Issue 0004: Hold 0,4 for arrow-key app cycling without order mutation

- Status: RESOLVED
- Slice-ID: hold-0-4-for-arrow-key-app-cycling-without-order-mutation
- Reported by: mayor
- Source: user request

## Problem
The new `next_window` mapping supports single-press immediate switch, but there is no hold mode that lets the user continue cycling across all open apps with arrow keys while keeping app ordering stable.

## Requested outcome
- Holding launchpad button `0,4` enters app-switch cycle mode.
- Single press on `0,4` still switches immediately to the next app.
- While `0,4` is held, arrow keys cycle through all currently open apps.
- Cycling must not reorder the app list while in this mode.

## Notes
- Scope this to behavior rooted in `0,4` and app-switch navigation semantics only unless the slice SPEC expands scope.
