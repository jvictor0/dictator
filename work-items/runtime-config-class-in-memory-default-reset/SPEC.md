# SPEC: runtime-config-class-in-memory-default-reset

## Problem statement
Runtime configuration reset currently reloads `runtime-config.safe` from disk each time. We need configuration objects with explicit defaults and in-memory mutation semantics so reset can apply defaults by iterating config entries and calling `set`.

## Scope
- Add a runtime configuration class abstraction with:
  - `name`
  - `currentValue`
  - `defaultValue`
  - virtual/overridable `getOptions()`
  - virtual/overridable `set(...)`
- Implement two concrete configurations:
  - `model` (options from Ollama list endpoint)
  - `use_cloud` (boolean options)
- Read startup defaults from `runtime-config.safe`.
- Update reset action to iterate configuration list and call `set(defaultValue)` for each config instead of re-reading safe file at action time.
- Ensure set-path updates runtime behavior in memory for future dictation calls.

## In scope
- `apps/macos-client/Sources/DictatorCore`
- `apps/macos-client/Sources/DictatorApp/main.swift`
- Unit tests in `apps/macos-client/Tests/DictatorCoreTests`

## Out of scope
- iOS app changes
- Contract changes in `/contracts/dictation_v1.yaml`
- New external APIs

## Acceptance criteria
1. Runtime configuration abstraction exists with required properties and virtual methods.
2. Model options list path uses Ollama model listing (`/api/tags`).
3. `set` path updates runtime settings in memory and affects future runtime reads.
4. Startup defaults are sourced from `runtime-config.safe`.
5. Launchpad safe-reset action iterates config list and applies defaults via `set`.
6. Tests cover safe-default startup behavior, list call behavior, and in-memory reset behavior.
