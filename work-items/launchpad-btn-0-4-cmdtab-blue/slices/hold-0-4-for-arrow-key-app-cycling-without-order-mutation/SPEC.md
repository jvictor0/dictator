# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: hold-0-4-for-arrow-key-app-cycling-without-order-mutation

## Problem Statement
Pad `0,4` now performs immediate native `next_window` on press, but there is no hold session that allows continued app cycling with arrow keys while preserving a stable candidate order during that session.

## Goals
- Preserve existing single-press behavior on `0,4`: immediate switch to next eligible app.
- Add hold behavior on `0,4` so that physical arrow keys can continue cycling apps while the pad remains pressed.
- Ensure app cycling order does not mutate during an active hold session.

## In Scope
- Runtime behavior changes for Launchpad pad `0,4` (`next_window`) to support press/release lifecycle hooks.
- Add an app-cycle hold session state in app runtime, including:
  - snapshot/freeze of eligible app ordering at session start,
  - current index tracking,
  - session teardown on pad release.
- Add temporary arrow-key monitors active only during hold session and route arrow presses to cycle within frozen order.
- Keep default layout mapping at `0,4` as `next_window` with existing blue color.
- Add/update automated tests for lifecycle dispatch and order-freeze behavior.

## Out of Scope
- Remapping coordinates other than `0,4`.
- Color changes for any pad.
- Reworking global keyboard architecture beyond minimal monitor usage needed for this hold session.
- Public contract/schema changes in `/contracts/dictation_v1.yaml`.
- Workflow/governance/script changes.

## API/Type/Contract Changes
- Public contract: no change expected.
- Internal runtime/type changes expected:
  - `LaunchpadPageFactory` callback surface extended so `next_window` can signal both press and release (or equivalent start/end hooks).
  - App runtime adds hold-session model for frozen app-order cycling.
  - App runtime adds temporary arrow-key event monitor control tied to hold-session lifecycle.

## Acceptance Criteria
1. Pressing `0,4` still performs immediate native next-app switch on initial press.
2. Keeping `0,4` held starts a cycle session; releasing `0,4` ends that session.
3. While hold session is active, pressing left/up cycles backward and right/down cycles forward through the session's frozen app list.
4. The ordered app candidate list used during a hold session is captured once at session start and is not recomputed/reordered until session end.
5. Rapid app activations caused by cycling do not reorder the in-session traversal order.
6. Existing layout mapping and color for `0,4` remain `next_window` and `r:40 g:140 b:255`.
7. Neighbor mapping at `4,4` remains unchanged (`Command+C`, existing color).
8. Tests are added/updated to verify dispatch lifecycle (press/release), frozen-order traversal semantics, and no regression for neighboring mapping.
9. Implementer handoff explicitly states no spec/scope changes were made.

## Risks
- Arrow-key monitor lifecycle bugs could leave monitors armed after release.
- Eligibility snapshot may include transient/non-activatable apps if filtering is inconsistent.
- Concurrent runtime state updates could cause index drift if hold-session state is not serialized.

## Fallback Plan
- If monitor interception/control is unreliable in some environments, keep monitors passive and still enforce deterministic app activation behavior from observed arrow presses; document the limitation in implementer notes.
- If no eligible app candidates exist at session start, treat hold mode as no-op and log reason.
- If implementation discovers a blocker requiring scope expansion, implementer must stop and record blocker per governance policy.
