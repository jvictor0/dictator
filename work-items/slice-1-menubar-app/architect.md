# Architect Notes

## Design rationale
- Keep Slice 1 minimal and avoid forward features from later slices.
- Use a single `MenuBarController` that configures title and menu on initialization.
- Keep title as constant (`Dictator`) for direct testability.
- Expose a pure helper (`makeMenu`) so unit tests can validate menu shape without driving full app lifecycle.

## Tradeoffs
- `NSStatusItem` visibility itself is not directly unit-testable without full GUI runtime.
- We mitigate with static menu/title unit tests plus manual launch evidence.

## Interfaces
- `MenuBarController.init()` now has no dependencies.
- `MenuBarController.statusTitle` and `MenuBarController.makeMenu(target:)` are test targets.

## ADR impact
- No ADR update needed; no architecture direction change.
