# Implementer pass 4

## Scope
Address additional UX feedback for overlay behavior and right-pane expansion ergonomics.

## Fixes
- Dock visibility: switched overlay presentation option from auto-hide to forced hide while overlay is visible (`.hideDock`), restoring prior presentation options on close.
- Expansion anchoring: when toggling a right-panel section, maintain the selected section's top-edge screen position (top stays fixed instead of drifting).
- Interaction switching stability: preserve right-panel scroll position when left-list interaction selection changes.

## Files updated
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadFullscreenOverlay.swift`
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadInteractionsOverlayTab.swift`
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`

## Validation
- `swift test` passed (97 tests, 0 failures).
