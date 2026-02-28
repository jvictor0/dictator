# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: replace-command-tab-mapping-with-immediate-native-next-window-switch

## Problem Statement
Launchpad coordinate `0,4` currently sends `Command+Tab` via synthetic keystroke. That behavior does not provide immediate one-button switching semantics and depends on modifier-state behavior that is unsuitable for this workflow.

## Goals
- Replace the `0,4` Command+Tab key-chord mapping with a native immediate next-window switch action.
- Preserve single-press behavior (no modifier hold/release dependency).
- Keep the `0,4` blue color and leave all other pad mappings unchanged.

## In Scope
- Extend Launchpad action model to represent a native next-window switch action (non-keystroke).
- Wire action execution through Launchpad page dispatch and app runtime integration.
- Update default Launchpad layout at coordinate `0,4` to use the new action type.
- Add/update automated tests for decode/dispatch and default mapping assertions.

## Out of Scope
- Remapping any coordinates other than `0,4`.
- Color changes beyond preserving existing `0,4` blue.
- Workflow/governance/script changes.
- Public API contract changes in `/contracts/dictation_v1.yaml`.

## API/Type/Contract Changes
- Public contract: no change expected.
- Internal type change: add a Launchpad action type for native next-window switching.
- Internal runtime behavior change: `0,4` no longer routes through `KeyboardInjector` with `Command+Tab`.

## Acceptance Criteria
1. Default Launchpad layout maps coordinate `0,4` to the new native next-window action type.
2. Pressing `0,4` executes immediate native next-window selection without requiring command-key release behavior.
3. Coordinate `0,4` remains blue (`r:40 g:140 b:255`).
4. Existing neighboring mapping at `4,4` remains unchanged (`Command+C`, same color).
5. Tests are updated/added to verify (1), (3), and dispatch path coverage for the new action type.
6. Implementer handoff explicitly states that scope/spec were not changed.

## Risks
- Native next-window selection may not exactly match macOS app-switcher MRU ordering in all edge cases.
- Window selection may fail when there is no eligible next window/app candidate.
- Permission/state differences could prevent activation on some machines.

## Fallback Plan
- Implement best-effort native activation of the next eligible visible window/app and log explicit failure reasons.
- If no eligible target exists, treat action as no-op with trace logging (no synthetic Command+Tab fallback in this slice).
- If implementation hits an unexpected platform blocker requiring scope expansion, implementer must stop and record blocker per governance policy.
