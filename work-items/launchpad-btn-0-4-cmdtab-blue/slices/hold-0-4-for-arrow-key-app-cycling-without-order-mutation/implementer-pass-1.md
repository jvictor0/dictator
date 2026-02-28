# Implementer Pass 1

## Change Summary By File
- `apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - Extended `LaunchpadPageFactory` callback surface for `next_window` to support both press and release callbacks.
  - Added `next_window` press dispatch logging and explicit release dispatch from pad release events.
  - Kept `next_window` non-repeating behavior.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Wired Launchpad `next_window` press/release callbacks to dedicated runtime handlers.
  - Added hold-session lifecycle (`start`, `arrow-cycle while active`, `end on release`) for `0,4` app switching.
  - Added frozen candidate snapshot usage for in-session traversal order stability.
  - Added temporary arrow key monitor arm/disarm tied to hold-session lifecycle and app termination cleanup.
  - Added directional mapping (`left/up` backward, `right/down` forward) and wraparound traversal behavior.
- `apps/macos-client/Sources/DictatorApp/LaunchpadAppCycleState.swift`
  - Added app-cycle state/session model for frozen candidate ordering and directional stepping.
- `apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`
  - Added `next_window` press/release lifecycle dispatch test.
  - Added frozen-order cycle state tests for forward/backward wraparound and teardown/no-op-after-stop behavior.

## Test Evidence
- Ran:
  - `swift test --package-path /Users/joyo/dictator/apps/macos-client --filter 'LaunchpadTests/(testPageFactoryDispatchesNextWindowPressAndReleaseActions|testAppCycleStateUsesFrozenOrderForSession|testAppCycleStateSupportsBackwardWraparound|testAppCycleStateStopsAndIgnoresFurtherSteps|testDefaultLayoutMapsZeroFourToNextWindowWithBlueColor)'`
- Result:
  - 5 tests executed, 0 failures.
  - Verified:
    - `next_window` press and release callbacks fire.
    - Frozen order traversal remains deterministic within session.
    - Backward/forward wraparound behavior.
    - Session stop clears state and ignores subsequent steps.
    - `0,4` mapping/color and neighbor mapping regression expectation stays valid.

## Known Limitations
- Arrow-key handling uses event monitors and debouncing to avoid duplicate dispatch across global/local monitor observations; monitor behavior can vary by focus context.
- Activation skips non-eligible/non-activatable apps but does not rebuild the frozen snapshot until next hold session (intentional per spec).

## Rollback Notes
- To roll back this slice safely, revert:
  - `apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - `apps/macos-client/Sources/DictatorApp/main.swift`
  - `apps/macos-client/Sources/DictatorApp/LaunchpadAppCycleState.swift`
  - `apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`

## Spec Compliance Statement
- `SPEC.md` scope was not modified in this implementer pass.

pass complete
