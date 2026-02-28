# Architect Notes

## Scope Decision
This slice replaces only the `0,4` Launchpad action behavior: remove synthetic `Command+Tab` mapping and introduce an immediate native next-window switch action. Color stays blue, and no other pad mappings are changed.

## Design Rationale
- Keystroke simulation for `Command+Tab` does not satisfy one-button immediate-switch semantics.
- A first-class Launchpad action type keeps behavior explicit and avoids overloading keystroke logic.
- Encapsulating native switch behavior behind a dedicated runtime handler keeps Launchpad parsing and execution paths maintainable.

## Proposed Implementation
1. Extend `LaunchpadActionConfig.ActionType` with a new case (for example `next_window`).
2. Update layout validation in `LaunchpadLayoutLoader.validate` to accept the new action type with no extra payload.
3. Extend `LaunchpadPageFactory`:
- add `onNextWindowSwitch` callback dependency,
- dispatch callback in `runAction` for the new action type,
- mark repeat behavior as disabled for this action.
4. In app runtime (`main.swift`), inject callback from page factory to a new handler that performs native immediate next-window switching (no keyboard chord injection).
5. Update `Config/launchpad-layout.json` coordinate `0,4` to the new action type while preserving existing blue color.
6. Update tests in `LaunchpadTests.swift`:
- layout decode accepts new action type,
- default layout asserts `0,4` new action + unchanged blue color,
- page factory dispatch invokes new callback.

## Tradeoffs
- Native next-window selection can be immediate but may not perfectly mirror every `Command+Tab` MRU nuance.
- Explicit action typing increases enum surface area but makes behavior and tests clearer.

## Interface and Contract Impact
- No change to `/contracts/dictation_v1.yaml`.
- No ADR required for this scoped behavioral mapping adjustment.

## Risks and Mitigations
- Risk: no eligible next window.
- Mitigation: treat as no-op with trace log; do not fall back to synthetic Command+Tab in this slice.
- Risk: regression in neighboring mappings.
- Mitigation: keep and enforce neighbor regression assertions in tests (`4,4` remains `Command+C`).

## Handoff
Architect pass complete. `SPEC.md` is approved for implementer pass 1.
pass complete
