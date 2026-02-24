# Implementer pass 2

## Scope addressed
- Added position-independent button/cell abstraction for overlay tab selectors.
- Ensured tab selector buttons are not present on grid when GUI is hidden.

## Changes made
- Refactored `LaunchpadOverlayTabButtonLayer` to model tab selectors as independent cell objects (`TabSelectorCell`) implementing `LaunchpadCellType`.
- Added coordinate assignment abstraction to `LaunchpadOverlayTabButtonLayer`:
  - buttons are identity-first (tab index)
  - coordinates are assigned separately (`assignCoordinates(...)`)
- Added dirty invalidation when selected tab changes and when coordinate assignment changes.
- Updated `LaunchpadOverlayTabSlotCoordinator` to construct layer with invalidation bus support.
- Retained slot lifecycle behavior: overlay hidden => layer removed from slot, so selector buttons do not exist on grid.
- Added new test `testOverlayTabButtonLayerSupportsCoordinateReassignment`.

## Constraints followed
- No changes to spec scope.
- Existing slot add/remove architecture preserved.
