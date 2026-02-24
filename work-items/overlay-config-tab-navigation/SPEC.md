# SPEC: overlay-config-tab-navigation

## Problem statement
The fullscreen overlay currently uses placeholder tabs. We need the first tab to become a runtime configuration view that shows config names and current values, and supports keyboard-driven selection/update from Launchpad arrow keys.

## Scope
- Replace first placeholder tab with a `config` tab.
- Render tab content as a two-column table:
  - Left: config name
  - Right: current value
- Add keyboard navigation behavior while overlay is visible:
  - Up/Down: move selected config row
  - Left/Right: cycle selected config through `getOptions` and apply `set`
- Ensure existing MIDI arrow pads can drive this behavior through current keystroke path.

## In scope
- `apps/macos-client/Sources/DictatorApp`
- `apps/macos-client/Tests/DictatorAppTests`

## Out of scope
- Launchpad layout changes
- DictatorCore contract changes
- iOS app behavior

## Acceptance criteria
1. First overlay tab title is `config`.
2. Config tab displays two columns (`Config`, `Current Value`) with runtime values.
3. While overlay is visible, up/down arrows change selected config row.
4. While overlay is visible, left/right arrows cycle and apply options from `getOptions` for selected config.
5. Existing non-overlay key dispatch behavior remains intact when overlay does not handle key.
6. Tests validate overlay key routing and config tab arrow-based selection/cycling.
