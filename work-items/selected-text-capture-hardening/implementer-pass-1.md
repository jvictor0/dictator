# Implementer Pass 1

## Files changed
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/ClipboardInserter.swift`
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/SmokeTests.swift`
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift` (existing tracing request from previous step retained)

## Implementation summary
- Added selected-text capture hardening in `ClipboardInserter`:
  - Track pre-copy `changeCount`.
  - Wait up to 250ms for pasteboard change after synthetic `Cmd+C`.
  - Accept selected text only when `currentChangeCount > priorChangeCount`.
  - Continue using existing normalization and clipboard restore.
- Added testable helpers:
  - `extractSelectedText(...)`
  - `waitForPasteboardChange(...)`
- Added tests for stale clipboard rejection and robust acceptance criteria.

## Acceptance criteria mapping
- AC1/AC2: enforced via `extractSelectedText` and `changeCount` gate.
- AC3: existing `normalizedSelectedText` remains in path.
- AC4: added three tests in `SmokeTests`.
- AC5: `swift test` passes.
