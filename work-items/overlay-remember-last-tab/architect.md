# Architect notes

## Design
- Persist selected overlay tab index in `UserDefaults` via `LaunchpadFullscreenOverlayController`.
- Restore persisted index when content controller/window is initialized.
- Remove reset-to-first-tab behavior on hide.

## Tradeoffs
- Persisting in controller keeps state ownership local and testable via injected defaults/key.
