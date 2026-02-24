# SPEC: Launchpad Overlay With Slot-Managed Tab Buttons

## Problem Statement
The macOS Launchpad integration needs a full-screen overlay UI toggled from Launchpad. The overlay must support top tabs and tab selection from Launchpad. Tab selector buttons must only exist when the overlay is visible, and they must be physically added to and removed from the controller as state changes.

## Scope
1. Add a Launchpad action to toggle a full-screen overlay from coordinate `(7,8)`.
2. Implement a full-screen overlay window with top tabs and placeholder tab content.
3. Pressing the toggle button again hides the overlay and resets to initial tab.
4. Pressing `(i,9)` selects tab index `i` (zero-based) while overlay is visible.
5. Tab selector buttons are removed from the controller when overlay is hidden.
6. Active tab selector buttons are lit; selected tab is highlighted.
7. Introduce slot-based control-layer abstractions in the launchpad controller so layers can be attached/detached by slot.
8. Add tests for DSL action support, action dispatch, and slot add/remove behavior for tab buttons.

## Out of Scope
- Production tab content beyond placeholders.
- Mouse-driven overlay interactions.
- LED animation effects.

## Interface Additions
- `LaunchpadActionConfig.ActionType.toggleFullscreenOverlay`
- `LaunchpadFullscreenOverlayController`
- `LaunchpadOverlayTab`
- `LaunchpadOverlayTabButtonLayer`
- `LaunchpadOverlayTabSlotCoordinator`
- Slot APIs on `LaunchpadPageController`:
  - `setControlLayer(_:forSlot:)`
  - `removeControlLayer(forSlot:)`
  - `clearControlLayers()`

## Acceptance Criteria
1. Press `(7,8)` toggles overlay show/hide.
2. Overlay has top tabs with placeholder content.
3. Hide resets overlay to initial tab.
4. While visible, `(i,9)` selects tab `i`.
5. While hidden, tab selector buttons are absent from controller slots.
6. Active tab selector buttons light up; selected tab uses a distinct color.
7. Tests cover new DSL action and slot-managed active/inactive behavior.

## Compatibility
- No changes to `/contracts/dictation_v1.yaml`.
- Existing launchpad controls keep current behavior.
