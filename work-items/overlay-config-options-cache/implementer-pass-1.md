# Implementer pass 1

## Summary
Implemented lazy `getOptions` loading with per-config caching for the overlay config tab, and cache clear on overlay close.

## Changes
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfiguration.swift`
  - `list()` now returns snapshots without options.
  - Added `getOptions(name:)`.
  - Added `snapshotWithoutOptions()` helper.

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadOverlayConfigTab.swift`
  - Added `getOptionsForConfig` closure.
  - Added `optionsCache` keyed by config name.
  - Left/right now fetches options once and reuses cache.
  - Implemented `overlayDidClose()` to clear cache/reset load state.

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadFullscreenOverlay.swift`
  - Added `overlayDidClose()` hook in tab protocol.
  - Overlay controller calls close hook on hide.

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Wired new `getOptionsForConfig` closure using manager `getOptions(name:)`.

- Tests:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigurationManagerTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`

## Validation
- Command: `swift test`
- Workdir: `/Users/joyo/dictator/apps/macos-client`
- Result: pass (`81` tests, `0` failures)
