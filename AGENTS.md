# AGENTS

This file defines role orchestration and minimum delivery standards for this repository.

## Roles

- `architect`: design interfaces, tradeoffs, and ADR updates
- `implementer`: implement scoped changes against approved spec and architecture
- `reviewer`: perform code review focused on regressions, risks, and contract drift
- `tester`: validate behavior with automated/manual evidence and quality sign-off

## Work item folder (required)

Each task must use a dedicated folder: `/work-items/<work-item-id>/`.

Minimum files:

- `SPEC.md`: architect-approved scope and acceptance criteria (source of truth)
- `architect.md`: architecture notes and design rationale
- `implementer-pass-1.md`: implementation handoff for reviewer
- `reviewer-pass-1.md`: review findings/approval
- `tester.md`: test evidence and release confidence

Optional files:

- `implementer-pass-2.md`
- `reviewer-pass-2.md`

## Workflow order

1. `architect` creates/updates `SPEC.md`.
2. `implementer` executes against `SPEC.md`.
3. `reviewer` reviews.
4. If reviewer finds issues, route back to implementer.
5. Maximum implementer attempts: 2 passes total.
6. If still failing after pass 2, implementer records blocker reason and stops (no architect escalation by default).
7. `tester` validates only after reviewer approval.
8. If tester finds a legitimate bug, route back to implementer, then back through reviewer before returning to tester.

Do not skip a role without documenting a reason in the work item notes.

## Role constraints

- Implementer may not change spec/scope in `SPEC.md`.
- If spec is insufficient or conflicting, implementer must record a blocker and stop.
- Tester may not change production code.
- Tester may only add/adjust test evidence artifacts unless explicitly reassigned.

## PR quality gates

- Contract compatibility with `/contracts/dictation_v1.yaml`
- Tests added/updated for changed behavior
- No unresolved `P0/P1` findings from reviewer or tester
- Documentation updated when interface behavior changes
- Work item handoff files are complete for the executed passes

## Branching and commits

- Branch prefix: `codex/`
- Keep commits scoped and descriptive
- Do not squash away meaningful review history while a PR is open
