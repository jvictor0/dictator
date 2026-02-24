# Implementer pass 1

## Summary
Implemented a real `config` overlay tab with two-column runtime config table and arrow-key navigation/cycling. Wired overlay key handling so Launchpad arrow pads drive config selection and value updates via `getOptions` + `set`.

## Files changed
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadFullscreenOverlay.swift`
  - Added overlay-tab async key handling contract.
  - Added controller/content forwarding for handled overlay keys.

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadOverlayConfigTab.swift` (new)
  - Added `LaunchpadConfigOverlayTab`.
  - Added two-column table view (`Config`, `Current Value`).
  - Added up/down selection and left/right option cycling (calls runtime config list/set closures).

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Replaced first placeholder tab with `config` tab.
  - Wired tab list/set closures to `RuntimeConfigurationManager`.
  - Intercepted arrow keys for overlay handling before keyboard injection fallback.

- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`
  - Added tests for overlay key routing and config-tab arrow navigation/cycling.

## Validation
- Command: `swift test`
- Workdir: `/Users/joyo/dictator/apps/macos-client`
- Result: pass (`81` tests, `0` failures)

## Spec conformance
- First tab is now `config`.
- Two-column config/value table is present.
- Up/down and left/right behavior implemented and test-covered.
- Overlay key fallback preserves prior behavior when not handled.
