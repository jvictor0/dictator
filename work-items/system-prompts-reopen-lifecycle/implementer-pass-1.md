# Implementer pass 1

## Changes made
- Added `refreshSelectedTabContent()` to overlay content controller.
- Updated overlay controller `show()` to call selected-tab refresh when reopening an existing overlay window.
- Added regression assertion to existing persistence test to verify selected tab view is rebuilt on reopen (`makeContentViewCount == 2`).
- Extended `FakeOverlayTab` test helper with `makeContentViewCount` tracking.

## Notes
- This addresses lifecycle contract comprehensively for all tabs, including System Prompts.
