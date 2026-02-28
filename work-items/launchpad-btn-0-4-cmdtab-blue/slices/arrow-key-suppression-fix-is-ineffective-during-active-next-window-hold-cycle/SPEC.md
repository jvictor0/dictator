# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: arrow-key-suppression-fix-is-ineffective-during-active-next-window-hold-cycle

## Problem Statement
The prior arrow-suppression slice did not fully resolve behavior: while `0,4` next-window hold-cycle is active, arrow keys can still reach the foreground app in at least one runtime path. Current suppression relies on `NSEvent` local monitor consumption, which is not sufficient when Dictator is not the active app.

## Goals
- Make arrow suppression reliable during active `0,4` hold-cycle, including when another app is frontmost.
- Preserve hold-cycle navigation semantics (`left/up` backward, `right/down` forward).
- Keep normal arrow-key delivery unchanged outside active hold-cycle sessions.

## In Scope
- Replace/augment current hold-cycle arrow suppression path so suppression works for foreground apps outside Dictator.
- Introduce a hold-session-scoped keyboard interception component (Quartz event tap path) for arrow-key `keyDown` events.
- Keep monitor/session lifecycle bounded to `0,4` hold-cycle start/end and app shutdown.
- Ensure cycle stepping remains single-action per physical arrow event (no double-step from parallel paths).
- Add/update tests for suppression decision logic and event-path arbitration.

## Out of Scope
- Remapping any Launchpad coordinates or changing pad colors.
- Reworking next-window candidate ordering/session model beyond what is required for reliable suppression.
- Public contract/schema changes in `/contracts/dictation_v1.yaml`.
- Workflow/governance/script changes.

## API/Type/Contract Changes
- Public contract: no change.
- Internal runtime changes expected:
  - add a dedicated hold-cycle arrow interception unit capable of consuming events before foreground app delivery,
  - unify arrow handling through a single decision path that both suppresses and steps cycle state while hold session is active.

## Acceptance Criteria
1. During an active `0,4` hold-cycle session, physical arrow `keyDown` events are consumed and do not reach the foreground app, including when Dictator is not frontmost.
2. During the same active session, consumed arrows still drive app-cycle traversal with existing direction mapping.
3. Outside active hold-cycle session, arrow events are not consumed by hold-cycle logic and normal foreground-app behavior is restored.
4. No double-cycle step occurs per physical arrow press while hold session is active.
5. Hold-session teardown (`0,4` release, app terminate, or safety stop) disables interception and restores normal keyboard delivery.
6. Existing `0,4` mapping/color and neighboring mapping assertions remain unchanged.
7. Tests are added/updated for: active-vs-inactive consumption behavior, no-double-step routing, and lifecycle arm/disarm boundaries.
8. Implementer handoff explicitly states no spec/scope changes were made.

## Risks
- Event-tap enablement may fail due to permission/state constraints or run-loop wiring mistakes.
- Incorrect interception filtering could over-consume non-arrow keys.
- Simultaneous monitor and event-tap handling can reintroduce duplicate cycle events.

## Fallback Plan
- If event tap cannot be armed, degrade to current behavior with explicit trace logs and do not claim suppression guarantee; implementer must document this as a limitation.
- Keep filtering strict: consume only arrow `keyDown` when hold session is active.
- Route all hold-session arrow stepping through one canonical handler and disable/guard alternate duplicate paths.
- If implementation requires broader architecture changes beyond this scope, implementer must stop and record blocker per governance policy.
