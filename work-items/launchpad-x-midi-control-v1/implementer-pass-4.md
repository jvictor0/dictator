# Implementer Pass 4

## Scope Delivered
Added command shortcut pads in row 4, columns 4-7 and ensured Shift state-machine behavior composes correctly with these keys.

## Changes
- `apps/macos-client/Config/launchpad-layout.json`
  - Added:
    - `(4,4)` -> Cmd+C
    - `(5,4)` -> Cmd+V
    - `(6,4)` -> Cmd+X
    - `(7,4)` -> Cmd+Z
  - Assigned distinct green shades for each.
- `apps/macos-client/Sources/DictatorApp/KeyboardInjector.swift`
  - Added keys: `c`, `v`, `x`, `z`.
  - Added modifiers: `command`, `option`, `control` (plus existing `shift`).
  - Event flags now include all supported modifiers.
- `apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - Added optional per-keystroke modifier list (`modifiers`) in DSL.
  - Keystroke callback now passes both key and base modifiers.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Keystroke dispatch now merges base DSL modifiers with Shift latch state-machine modifiers.

## Shift Interaction Guarantee
- For Cmd shortcuts, base `command` modifier is always applied.
- Shift behavior is still governed by the 4-state machine:
  - Arrow keys in latched state keep shift active.
  - Non-arrow keys (including Cmd shortcuts) unlatch as specified.
  - While Shift is physically pressed, non-arrow keypresses include Shift and transition to no-latch-on-release.

## Test Evidence
Command:
- `swift test` in `apps/macos-client`

Result:
- 36 tests passed, 0 failures.

## Spec Integrity
- Changes remain in-scope for Launchpad interaction DSL + input behavior; no external API contract drift.
