# Implementer Pass 1

## Change summary by file
- `apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - Added new Launchpad action type `next_window` (`LaunchpadActionConfig.ActionType.nextWindow`).
  - Updated layout validation to accept `next_window` as a no-payload action.
  - Extended `LaunchpadPageFactory` with `onNextWindowSwitch` callback injection.
  - Added dispatch path for `next_window` action in `runAction`.
  - Marked `next_window` as non-repeating in cell repeat behavior.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Wired new `onNextWindowSwitch` callback from Launchpad page factory setup.
  - Implemented native immediate next-window/app switching handler (`handleLaunchpadNextWindowSwitch`).
  - Added helper (`orderedWindowOwnerPIDs`) that derives ordered candidate app PIDs from on-screen window ownership via `CGWindowListCopyWindowInfo`.
  - Behavior is best-effort native activation only; no synthetic `Command+Tab` fallback.
- `apps/macos-client/Config/launchpad-layout.json`
  - Updated coordinate `(0,4)` action from keystroke `Command+Tab` to `{"type":"next_window"}`.
  - Preserved `(0,4)` blue color (`r:40 g:140 b:255`).
  - Left neighboring `(4,4)` mapping unchanged.
- `apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`
  - Added decode acceptance test for `next_window` action type.
  - Updated default-layout assertion test to require `(0,4)` action type `nextWindow` and preserved blue color.
  - Added page-factory dispatch test for `next_window` callback.
  - Updated existing `LaunchpadPageFactory` test callsites for new initializer parameter.

## Test evidence
- Command run:
  - `swift test --package-path /Users/joyo/dictator/apps/macos-client --filter LaunchpadTests`
- Result:
  - PASS
  - 32 tests executed, 0 failures
  - Includes coverage of:
    - layout decode for `next_window`
    - default `(0,4)` mapping and color
    - dispatch path invocation for `next_window`
    - unchanged neighbor `(4,4)` command mapping assertions

## Known limitations
- Native next-window behavior is based on current on-screen window owner ordering plus a running-app fallback, which may not perfectly match macOS app-switcher MRU ordering in all edge cases.
- If there is no eligible visible app/window candidate, action is a no-op with trace logging.

## Rollback notes
- To revert this slice behavior, restore `(0,4)` in `apps/macos-client/Config/launchpad-layout.json` to keystroke `Command+Tab` and remove `next_window` action wiring:
  - `LaunchpadActionConfig.ActionType.nextWindow`
  - `LaunchpadPageFactory.onNextWindowSwitch` callback and dispatch case
  - `handleLaunchpadNextWindowSwitch` / `orderedWindowOwnerPIDs` in `main.swift`
  - corresponding `LaunchpadTests` additions/updates

## Spec compliance statement
- `SPEC.md` scope was not changed during this implementer pass.

pass complete
