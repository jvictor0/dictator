# SPEC: Overlay reopen lifecycle should refresh selected tab content

## Scope
Fix the overlay lifecycle so reopening the UI on the same selected tab properly repopulates tab content after close/open cycles.

## Problem statement
After tab persistence was introduced, hiding the overlay still triggered `overlayDidClose()` (which clears tab state), but reopening did not re-render the currently selected tab when the selected tab index was unchanged. This left tabs blank until a tab switch forced rerender.

## Acceptance criteria
1. Reopening overlay always refreshes currently selected tab content.
2. Fix is lifecycle-level (overlay controller/content lifecycle), not tab-specific.
3. Regression test reproduces close/reopen-on-same-tab and verifies content view rebuild.
4. Existing tests remain green.
