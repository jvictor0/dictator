# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: first-arrow-press-skips-current-selection-in-hold-cycle-app-list

## Problem Statement
During active `0,4` next-window hold-cycle navigation, the first arrow key press can skip the expected adjacent selection. Existing behavior suggests hold-session snapshot/index seeding is anchored to the wrong starting position for the first directional step.

## Goals
- Make the first arrow press in an active hold-cycle session step to the correct adjacent app relative to the true current selection.
- Preserve frozen-order semantics for the remainder of the same hold-cycle session.
- Avoid regressions to hold-session lifecycle, arrow suppression, and non-hold arrow behavior.

## In Scope
- `apps/macos-client` hold-cycle state/index initialization and first-step behavior for `next_window` sessions.
- Runtime wiring in `main.swift` only as needed to pass correct current-selection context into cycle-state start logic.
- Unit tests for first-step behavior in both forward and backward directions, including missing-current fallback handling.

## Out of Scope
- Remapping any Launchpad coordinates or changing pad colors.
- Reworking event-tap/monitor interception architecture beyond changes strictly needed for first-step correctness.
- Public contract/schema changes in `/contracts/dictation_v1.yaml`.
- Workflow/governance/script changes.

## API/Type/Contract Changes
- Public contract: no change.
- Internal type/API changes are allowed if needed to encode explicit first-step semantics (for example, start-anchor strategy or equivalent cycle-state initializer input), but must remain scoped to hold-cycle internals.

## Acceptance Criteria
1. On hold-session start, cycle-state anchor/index reflects the true current selection used as baseline for navigation (no off-by-one seed).
2. First `right`/`down` arrow press moves exactly one position forward from the true current selection in frozen order.
3. First `left`/`up` arrow press moves exactly one position backward from the true current selection in frozen order.
4. After first step, subsequent steps continue traversing the same frozen candidate order with existing wraparound semantics.
5. If the baseline current selection is absent from the frozen list, behavior is deterministic and documented in code/tests (no unstable skipping).
6. Hold-session teardown/release behavior remains unchanged (`0,4` release ends session and clears cycle state).
7. Existing `0,4` mapping/color and neighbor mapping assertions remain unchanged.
8. Tests are added/updated to cover first-step forward/backward correctness and baseline-missing fallback.
9. Implementer handoff explicitly states no spec/scope changes were made.

## Risks
- Fixing first-step seed logic can accidentally invert or offset existing wraparound traversal.
- Incorrect baseline selection source (pre-switch vs post-switch frontmost) can pass some cases while failing real hold flow.
- Tight coupling with runtime lifecycle could introduce regressions in session start/stop if not isolated.

## Fallback Plan
- Prefer a minimal, explicit cycle-state rule for first-step anchoring rather than ad-hoc runtime conditionals.
- If ambiguity remains between baseline strategies, align behavior to observed runtime current selection at arrow dispatch time and encode with deterministic tests.
- If a required fix demands broader interaction model changes outside this scope, implementer must stop and record blocker per governance policy.
