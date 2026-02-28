# Architect Notes

## Scope Decision
This slice is limited to keyboard-delivery behavior during `0,4` next-window hold-cycle: arrow keys should control cycle traversal and be suppressed from foreground app delivery only while the hold session is active.

## Design Rationale
- The current local monitor already observes arrow keys and routes cycle logic, so the minimal safe change is to convert it from pass-through to conditional consumption.
- Suppression must be session-gated to avoid changing normal arrow behavior outside hold mode.
- A small testable decision helper reduces AppKit-callback ambiguity and improves regression coverage.

## Proposed Implementation
1. Keep current monitor arming/disarming lifecycle tied to hold-session start/end.
2. In local key monitor callback, route through a MainActor helper that returns a consumption decision:
- returns `true` only when event is `.keyDown`, keyCode is an arrow key, and hold session is active,
- triggers existing arrow-cycle handler when consumed.
3. Return `nil` from local monitor when consumed; otherwise return original `event`.
4. Keep global monitor behavior for cycle continuity, but ensure duplicate-processing safeguards remain intact (existing debounce/session checks).
5. Keep `handleLaunchpadNextWindowSwitchRelease()` teardown behavior unchanged so suppression ends immediately on pad release.

## Tradeoffs
- Consuming in local monitor is the only mechanism that prevents keystroke delivery to focused apps; global monitor alone cannot do this.
- Maintaining both global and local monitors is slightly redundant but lowers risk for edge contexts where one monitor path may not fire consistently.

## Interface and Contract Impact
- No change to `/contracts/dictation_v1.yaml`.
- No ADR required; this is an internal behavior correction within existing hold-cycle architecture.

## Risks and Mitigations
- Risk: accidental suppression of non-arrow keys.
- Mitigation: explicit keyCode filter via existing `directionForArrowKeyCode` gating.
- Risk: suppression persists after session end.
- Mitigation: preserve idempotent disarm path in `endLaunchpadAppCycleSession` and verify boundary tests.
- Risk: double step events due to both monitor paths.
- Mitigation: preserve debounce and active-session checks already present in `handleLaunchpadArrowCycleKeyDown`.

## Test Guidance
- Add focused tests for the new consumption-decision helper:
- active session + arrow key => consumed.
- inactive session + arrow key => not consumed.
- active session + non-arrow key => not consumed.
- Add/adjust integration-level tests where feasible to verify local monitor callback returns `nil` for consumed arrows and non-`nil` otherwise.
- Keep existing regression tests for `0,4` mapping/color and next-window press/release dispatch.

## Handoff
Architect pass complete. `SPEC.md` is approved for implementer pass 1.
pass complete
