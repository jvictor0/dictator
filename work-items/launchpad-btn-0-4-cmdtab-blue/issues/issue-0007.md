# Issue 0007: First arrow press skips current selection in hold-cycle app list

- Status: RESOLVED
- Slice-ID: first-arrow-press-skips-current-selection-in-hold-cycle-app-list
- Reported by: mayor
- Source: user report

## Problem
During `0,4` hold-cycle app navigation, the first arrow key press appears to skip over the currently selected app/window. This suggests the frozen snapshot/index initialization is off by one or seeded to the wrong current position.

## Requested investigation
- Reproduce with active hold-cycle and verify first arrow press behavior against expected current selection.
- Audit snapshot construction and current-index seeding logic used at hold-session start.
- Confirm step behavior for first keypress in both forward and backward directions.

## Requested outcome
- First arrow press moves to the correct adjacent app relative to the true current selection (no unintended skip).
- Frozen-order semantics remain stable for the rest of the session.
- No regressions to hold-cycle teardown or non-hold arrow behavior.
