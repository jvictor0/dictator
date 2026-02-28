# Architect Notes

## Scope Decision
This slice keeps `0,4` as `next_window` but extends behavior to include a hold session: immediate switch on press remains, and while the same pad stays pressed, physical arrow keys cycle through a frozen list of eligible open apps. No remaps or color changes are included.

## Design Rationale
- Preserve user muscle memory and prior slice semantics by retaining the same action type and single-press behavior.
- Add explicit press/release lifecycle handling so hold state is deterministic and bounded.
- Freeze candidate order at hold-session start to prevent MRU/order mutation while cycling.

## Proposed Implementation
1. Extend `LaunchpadPageFactory` `next_window` handling to support both press and release callbacks (for example `onNextWindowSwitchPress` and `onNextWindowSwitchRelease`), while keeping other action behavior unchanged.
2. In app runtime (`main.swift`), split current `handleLaunchpadNextWindowSwitch()` responsibilities into:
   - immediate switch on press,
   - hold-session lifecycle start/end.
3. Introduce a hold-session state model (MainActor-owned) containing:
   - `isActive`,
   - frozen ordered candidate app identifiers (PID list),
   - current index within frozen list.
4. On `0,4` press:
   - build candidate list using existing eligibility filtering logic,
   - execute immediate next switch,
   - start hold session and arm arrow-key monitors.
5. While session active:
   - map physical arrow keys to direction (`left/up = -1`, `right/down = +1`),
   - move index through frozen list with wraparound,
   - activate selected app without rebuilding/reordering candidate list.
6. On `0,4` release:
   - disarm arrow-key monitors,
   - clear hold-session state.
7. Keep `apps/macos-client/Config/launchpad-layout.json` mapping at `0,4` unchanged (`next_window`, blue).

## Tradeoffs
- Using temporary `NSEvent` monitors is minimal and aligned with existing app patterns (backspace monitor), but may observe rather than fully intercept in some contexts.
- Freezing list per hold session improves determinism but means newly opened/closed apps are only reflected on the next hold start.

## Interface and Contract Impact
- No public API/contract changes (`/contracts/dictation_v1.yaml` unchanged).
- No ADR required: this is scoped behavioral refinement within existing Launchpad architecture.

## Risks and Mitigations
- Risk: monitor leak (not removed on all release paths).
  - Mitigation: centralize arm/disarm in idempotent helpers and call teardown from release and app shutdown path.
- Risk: stale/invalid PID in frozen list.
  - Mitigation: skip invalid/terminated apps during step activation and continue traversal.
- Risk: race conditions between monitor callbacks and Launchpad events.
  - Mitigation: keep hold-session mutations on MainActor and avoid cross-thread mutable state.

## Test Guidance
- `LaunchpadTests.swift`:
  - add/extend page-factory test coverage to assert `next_window` press and release callbacks both fire for pad `0,4`.
  - keep existing `0,4` mapping/color and `4,4` regression assertions.
- Add focused runtime unit tests (new test file if needed) for frozen-order cycle logic:
  - session captures ordered candidates once,
  - arrow step traverses frozen order with wraparound,
  - session teardown resets state and ignores subsequent arrows.
- If runtime unit isolation is not feasible in this pass, implementer must document rationale and provide highest-fidelity test coverage available.

## Handoff
Architect pass complete. `SPEC.md` is approved for implementer pass 1.
pass complete
