# Architect Notes

## Scope Decision
This slice is a corrective behavior fix for `0,4` hold-cycle arrow suppression reliability. It does not change pad mappings, colors, or candidate-order semantics; it only ensures arrow keys are actually suppressed during active hold-cycle across foreground-app contexts.

## Root-Cause Hypothesis
Current implementation suppresses arrows via `NSEvent.addLocalMonitorForEvents` return-`nil` behavior. Local monitors only affect events dispatched to this app, so they cannot reliably block arrow delivery while another app is frontmost (the common hold-cycle case after switching). A global monitor can observe but cannot suppress.

## Proposed Implementation
1. Add a dedicated runtime component (for example `LaunchpadArrowCycleEventTapController`) that owns a Quartz keyboard event tap for `keyDown` events.
2. Arm the event tap at hold-session start and disarm at hold-session end (`0,4` release), and also during app termination as a safety teardown.
3. In event-tap callback:
- fast-filter to arrow key codes only,
- consult hold-session-active state,
- when active, forward event metadata to main-thread cycle handler and return `nil` to consume,
- when inactive or non-arrow, pass event through unchanged.
4. Keep existing cycle stepping logic in one canonical method; ensure monitor-based paths do not process the same arrow event during active interception (remove or guard duplicate local/global paths as needed).
5. Keep debounce behavior only if still necessary after single-path routing; otherwise simplify to deterministic one-step-per-event.

## Tradeoffs
- Event taps provide true suppression but add lifecycle/run-loop complexity versus monitor-only approaches.
- Restricting the tap to hold-session windows minimizes blast radius and reduces risk of interfering with unrelated keyboard input.
- Consolidating to one event path improves correctness at the cost of minor refactoring in monitor wiring.

## Interface and Contract Impact
- No change to `/contracts/dictation_v1.yaml`.
- No ADR required; this is an internal runtime correctness fix within existing architecture.

## Risks and Mitigations
- Risk: tap creation fails or gets disabled by system state.
- Mitigation: explicit arm-state logging, defensive disarm, and documented degraded behavior.
- Risk: over-suppression of non-arrow keys.
- Mitigation: strict keyCode + hold-session gating before consumption.
- Risk: duplicate cycle steps.
- Mitigation: enforce single processing path for active-session arrows; add regression test coverage for one-step behavior.

## Test Guidance
- Add unit tests around interception decision logic:
- active session + arrow `keyDown` => consume.
- inactive session + arrow `keyDown` => passthrough.
- active session + non-arrow => passthrough.
- Add/adjust runtime-level tests (or best-isolated equivalent) to verify:
- lifecycle arm/disarm boundaries on press/release.
- no duplicate stepping per single arrow event while active.
- Preserve existing regression assertions for `0,4` mapping/color and neighbor pad behavior.

## Handoff
Architect pass complete. `SPEC.md` is approved for implementer pass 1.
pass complete
