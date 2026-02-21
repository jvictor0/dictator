# Implementer Pass 1

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/MenuBarController.swift`
  - Removed dictation toggle wiring.
  - Reduced menu to a single `Quit` action.
  - Added `statusTitle` constant and `makeMenu(target:)` helper for testability.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Removed `RecordingController` dependency from app startup.
  - Initialize `MenuBarController` directly.
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/SmokeTests.swift`
  - Replaced recording-toggle smoke check with Slice 1 checks for status title and menu quit item.
  - Kept API response decode smoke test intact.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Updated scope text to reflect Slice 1 state (menubar utility + quit, with future wiring points).

## Test evidence
- `swift build` (pass) in `/Users/joyo/dictator/apps/macos-client`.
- `swift test` (pass) in `/Users/joyo/dictator/apps/macos-client`.

## Known limitations
- Automated tests validate menu/title construction but cannot assert visible menubar rendering in headless mode.

## Rollback notes
- Revert edited files above to prior commit to restore pre-slice menu/toggle behavior.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during implementation.
