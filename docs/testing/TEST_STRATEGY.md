# Test Strategy

## Objectives

- Preserve API contract compatibility.
- Validate pipeline selection/failure behavior.
- Keep client smoke coverage for menubar and insertion path.

## Test layers

- Unit: adapter and pipeline logic
- Contract: payload compatibility against YAML spec
- Smoke: macOS client state transitions and in-process pipeline response handling

## Minimum CI checks

- `swift test` in `apps/dictator-main`

## Manual checks (later)

- Microphone permission behavior
- Accessibility/clipboard insertion behavior in real apps
