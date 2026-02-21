# Implementer Pass 2

## Trigger for pass 2
- Tester-reported legitimate bug: recording indicator did not visibly turn on in user environment.

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/MenuBarController.swift`
  - Replaced attributed-color-only indicator with explicit glyph states:
    - Idle: `🫡 ⚪`
    - Recording: `🫡 🔴`
  - Keeps behavior deterministic regardless of system title-color rendering.
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/SmokeTests.swift`
  - Updated indicator expectations to assert exact idle/active title strings.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Updated Slice 3 behavior docs for explicit indicator states.

## Test evidence
- `swift test` passed in `/Users/joyo/dictator/apps/macos-client` (8 tests, 0 failures).
- `swift build` passed in `/Users/joyo/dictator/apps/macos-client`.

## Known limitations
- Indicator is still symbol-based (not a custom icon asset), by design for slice scope.

## Rollback notes
- Revert the files above to restore prior attributed-color indicator behavior.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during pass 2.
