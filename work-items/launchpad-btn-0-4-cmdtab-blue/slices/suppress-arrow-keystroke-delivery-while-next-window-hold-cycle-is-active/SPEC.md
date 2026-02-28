# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: suppress-arrow-keystroke-delivery-while-next-window-hold-cycle-is-active

## Problem Statement
During launchpad `0,4` next-window hold-cycle mode, arrow-key input is currently used for app cycling but local key events are still returned to AppKit, so foreground apps can also receive those arrow keystrokes. The hold-cycle session should consume arrow keys for cycle control only.

## Goals
- While `0,4` hold-cycle session is active, consume arrow key events so they are not delivered to the focused app.
- Preserve existing hold-cycle navigation behavior (`left/up` backward, `right/down` forward).
- Keep all non-arrow key behavior unchanged.

## In Scope
- macOS client runtime event-monitor behavior for arrow keys during active next-window hold-cycle sessions.
- Local monitor return semantics (`NSEvent?`) for eligible arrow-key events while session is active.
- Focused tests for event-consumption decision logic and regression coverage for hold-session boundaries.

## Out of Scope
- Remapping any launchpad coordinate or color.
- Changes to candidate ordering, cycle-session start/stop semantics, or activation strategy beyond what is required for arrow suppression.
- Public contract/schema updates in `/contracts/dictation_v1.yaml`.
- Workflow/governance/script changes.

## API/Type/Contract Changes
- Public contract: no change.
- Internal behavior/type adjustments expected:
  - Runtime should expose a deterministic decision path for whether an incoming keyDown event is consumed by hold-cycle handling.
  - Local key monitor for hold-cycle should return `nil` for consumed arrow events during active session and return the original event otherwise.

## Acceptance Criteria
1. With an active `0,4` hold-cycle session, local arrow keyDown events (`left/up/right/down`) are consumed (not forwarded to the foreground app).
2. With an active hold-cycle session, those consumed arrow keys still drive app cycling in the same direction mapping as today.
3. Without an active hold-cycle session, arrow key behavior is unchanged and key events are not consumed by hold-cycle logic.
4. Non-arrow keyDown events remain unconsumed by hold-cycle logic regardless of session state.
5. Releasing `0,4` ends hold-cycle mode and immediately restores normal local event delivery for arrow keys.
6. Existing `0,4` mapping/color and adjacent mapping assertions remain unchanged.
7. Tests are added/updated to cover consumed-vs-forwarded behavior and hold-session boundary transitions.
8. Implementer handoff explicitly states no spec/scope changes were made.

## Risks
- Over-consuming local events could unintentionally block unrelated keyboard behavior.
- Divergence between global/local monitor paths could cause duplicate or missed cycle actions.
- Lack of isolatable tests around AppKit monitor callbacks can reduce confidence if not addressed with testable helper logic.

## Fallback Plan
- If direct monitor-level assertions are hard to test, extract event-consumption decision into a small pure helper and test that logic directly, while leaving monitor wiring minimal.
- If suppression causes regressions outside hold-cycle, gate suppression strictly on both session-active state and arrow-key detection, and log decision paths for debugging.
- If an implementation blocker requires broader architectural change, implementer must stop and record blocker per governance policy.
