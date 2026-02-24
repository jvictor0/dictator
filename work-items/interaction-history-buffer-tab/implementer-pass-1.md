# Implementer pass 1

## Summary
Implemented interaction capture + memory-bounded circular buffer and replaced the third overlay placeholder with a full Interactions tab.

## Key changes
- Added interaction domain model and circular buffer:
  - `apps/macos-client/Sources/DictatorApp/InteractionHistory.swift`
- Added Interactions overlay tab UI + keyboard navigation:
  - `apps/macos-client/Sources/DictatorApp/LaunchpadInteractionsOverlayTab.swift`
- Wired capture into dictation workflow and replaced placeholder tab:
  - `apps/macos-client/Sources/DictatorApp/main.swift`
- Added runtime config support for interaction buffer size:
  - `apps/macos-client/Sources/DictatorCore/RuntimeConfig.swift`
  - `apps/macos-client/Sources/DictatorCore/RuntimeConfiguration.swift`
  - `apps/macos-client/Config/runtime-config.json`
  - `apps/macos-client/Config/runtime-config.safe`

## Behavior details
- Interaction tracked size is `UTF8(whisperOutput).count + UTF8(finalOutput).count`.
- Buffer default is `100 MB` and evicts oldest entries first to remain under limit.
- Runtime config now exposes `Interactions Buffer` with MB options.
- Interactions tab left pane lists final outputs oldest->newest; default selection is newest.
- Up/down keys move selected interaction; right pane shows comprehensive details.

## Validation
- `swift test` in `apps/macos-client` (95 passing).
- `swift test --filter LaunchpadTests` in `apps/macos-client` (25 passing).
