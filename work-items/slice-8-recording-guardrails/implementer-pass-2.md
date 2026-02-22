# Implementer pass 2

## Bug addressed
- In Codex, focused-element AX lookup returned status `-25212` and incorrectly blocked recording start.

## Changes made
- Added fallback in `FocusedInputDetector`:
  - If focused AX element cannot be resolved and frontmost app matches `Codex`/`Cursor`, allow recording.
  - Include explicit fallback summary in diagnostics.
- Added regression test for role rejection baseline (`AXGroup`, non-editable).

## Outcome
- Codex false-negative focus detection path mitigated while keeping strict checks for other apps.
