# Implementer pass 1

## Changes made
- Added `FocusedInputDetector` with testable role logic.
- Updated `DictatorAppDelegate` to:
  - block recording start when no editable text input is focused,
  - arm/disarm Backspace monitors,
  - cancel/discard recording on Backspace while recording.
- Added selected no-op insertion path when revised text is empty.
- Updated backend pipeline to short-circuit empty STT transcript before refinement.
- Added/updated tests:
  - Python pipeline test to verify empty transcript skips LLM call.
  - Swift tests for focused-input role detection.
- Updated roadmap and macOS README behavior notes.

## Constraints followed
- No contract schema changes.
- Existing flow preserved when guardrails are not triggered.
