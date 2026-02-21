# Implementer Pass 1

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Added Slice 3 toggle flow using `RecordingController`.
  - Caps Lock press now toggles recording state; insert `hello world` only when toggling off.
  - Updated startup status text for recording-toggle semantics.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/MenuBarController.swift`
  - Added recording indicator rendering (`🫡 ●`) with active color while recording.
  - Added `setRecordingActive(_:)` and attributed-title builder.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/CapsLockTriggerController.swift`
  - Added duplicate-trigger suppression window to prevent global/local monitor double-firing.
  - Added testable trigger-acceptance helper.
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/SmokeTests.swift`
  - Added tests for status-title indicator, duplicate-trigger dedupe logic, and recording toggle state transitions.
  - Kept existing contract decode and clipboard snapshot tests.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Updated current behavior documentation to Slice 3.

## Test evidence
- `swift test` passed in `/Users/joyo/dictator/apps/macos-client` (8 tests, 0 failures).
- `swift build` passed in `/Users/joyo/dictator/apps/macos-client`.

## Known limitations
- Recording is state-only placeholder (no audio capture yet by slice design).
- Visual active indicator depends on menu bar attributed-title rendering in user environment.

## Rollback notes
- Revert touched files listed above to return to Slice 2 immediate-insert behavior.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during implementation.
