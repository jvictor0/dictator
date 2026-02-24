# Architect notes

## Design
- Remove only the app-level trigger path and Launchpad action for voice config mode changes.
- Keep core voice-config orchestration code unchanged to avoid unnecessary core API churn in this slice.
- Simplify recording flow to a single dictation path.
