# Implementer Pass 5

## Scope Delivered
Implemented Launchpad lifecycle quality-of-life controls:
1. auto-enter programmer mode on connect
2. idle sleep after 10 minutes
3. wake-on-touch with full LED repaint

## Changes
- `apps/macos-client/Sources/DictatorApp/LaunchpadMIDIManager.swift`
  - Added idle power-management state:
    - `idleSleepInterval = 600` seconds
    - idle timer arm/disarm on connect/disconnect
    - `isSleeping` gate to suppress LED traffic while sleeping
  - Added Launchpad-family power SysEx send helper:
    - `sendSleepMode(isAwake:)`
    - awake payload on connect and first input after sleep
    - sleep payload on idle timeout
  - Added wake/sleep notification callback:
    - `onSleepStateChanged: ((Bool) -> Void)?`
  - Connect flow now does:
    - programmer mode SysEx
    - explicit awake SysEx
    - idle timer start
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Wired `midiManager.onSleepStateChanged`:
    - updates menu status for sleeping state
    - triggers `renderWorker.invalidateAll()` on wake for full redraw recovery

## Notes on SysEx references
- Programmer mode for Launchpad Pro Mk3 is documented in Novation's Launchpad Pro Mk3 programmer reference.
- Sleep command behavior is implemented using Launchpad-family power-management command pattern (`... 09 <mode> ...`) and validated in-app behavior path (sleep timer/wake flow + redraw).

## Test Evidence
Command:
- `swift test` in `apps/macos-client`

Result:
- 36 tests passed, 0 failures.

## Spec Integrity
- Reactive renderer contract remains intact: no direct page/cell LED pushes introduced.
- Renderer remains sole LED writer, with wake path forcing full diff-frame rebuild.
