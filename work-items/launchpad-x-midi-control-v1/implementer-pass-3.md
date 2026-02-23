# Implementer Pass 3

## Scope Delivered
Implemented a latching Shift modifier key with the requested four-state behavior and integrated it with DSL-driven key dispatch. Also added the space key at `(4,7)` and maintained keyboard-style hold repeat behavior.

## Shift State Machine
States:
1. `Unpressed`
2. `Pressed - will latch on release`
3. `Pressed - will not latch on release`
4. `Latched`

Behavior implemented:
- Press Shift -> enter `Pressed - will latch on release`.
- Release Shift from that state -> enter `Latched`.
- While `Latched`, arrow keys keep latch active and are sent with Shift modifier.
- While `Latched`, any non-arrow key unlatches immediately before dispatch.
- If Shift is pressed and a non-arrow key is pressed before Shift release, state changes to `Pressed - will not latch on release`; Shift release then returns to `Unpressed`.

## Change Summary by File
- `apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - Added DSL action `modifier_latch` with `modifier: shift`.
  - Added role `shift_latch`.
  - Added callbacks for keystroke dispatch and modifier press/release handling.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Added Shift state machine and transition logic.
  - Added modifier-aware keyboard dispatch path.
- `apps/macos-client/Sources/DictatorApp/KeyboardInjector.swift`
  - Added `KeyboardModifier` support and modifier flags on emitted events.
  - Added `space` key support.
- `apps/macos-client/Sources/DictatorApp/LaunchpadPage.swift`
  - Added hold-repeat timer behavior for repeatable keys.
- `apps/macos-client/Config/launchpad-layout.json`
  - Added space key at `(4,7)`.
  - Added Shift latch key at `(5,6)`.
- `apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`
  - Added tests for `space` decode, repeat behavior, and modifier latch DSL decoding.

## Test Evidence
Command:
- `swift test` (run in `apps/macos-client`)

Result:
- Build succeeded.
- 36 tests passed, 0 failures.

## Known Limitations
- Shift latch is currently hardcoded to a single modifier (`shift`).
- Shift state behavior is implemented in app runtime logic and not yet split into a standalone unit-tested state-machine type.

## Spec Integrity
- Changes stay within Launchpad control workflow scope and do not modify external API contracts.
