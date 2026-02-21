# Test Strategy

## Objectives

- Preserve API contract compatibility.
- Validate pipeline selection/failure behavior.
- Keep client smoke coverage for menubar and insertion path.

## Test layers

- Unit: adapter and pipeline logic
- Contract: payload compatibility against YAML spec
- Smoke: macOS client state transitions and API response handling

## Minimum CI checks

- `pytest` in `services/orchestrator`
- `swift test` in `apps/macos-client`

## Manual checks (later)

- Microphone permission behavior
- Accessibility/clipboard insertion behavior in real apps
