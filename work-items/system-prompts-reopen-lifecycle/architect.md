# Architect notes

## Design
- Keep tab persistence behavior.
- Treat overlay reopen as an explicit visibility lifecycle event for selected tab content.
- In `LaunchpadFullscreenOverlayController.show()`, when reusing an existing window/controller, explicitly refresh selected tab content via content controller.

## Why this is the right layer
- Root cause is controller lifecycle mismatch (`overlayDidClose` without corresponding selected-tab refresh on reopen), not a bug inside System Prompts tab.
- Fixing controller lifecycle guarantees all tabs receive consistent behavior.
