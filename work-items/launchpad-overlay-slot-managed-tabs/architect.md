# Architect notes

## Design summary
- Reuse existing Launchpad DSL pipeline by introducing `toggle_fullscreen_overlay` as an action type.
- Add a dedicated overlay controller for full-screen window + tab rendering.
- Extend `LaunchpadPageController` with slot-based control-layer management, allowing dynamic registration/removal of button layers.
- Implement a focused coordinator (`LaunchpadOverlayTabSlotCoordinator`) that maps overlay state to slot operations:
  - visible => install tab button layer into slot
  - hidden => remove tab button layer from slot
- Keep tab button colors in the layer implementation to centralize rendering behavior.

## Tradeoffs
- Slot ordering is deterministic by insertion order; future priority needs can be added as metadata if required.
- Overlay remains non-mouse-interactive to avoid focus/selection regressions.

## Compatibility
- Additive changes only; no contract shape modifications.
