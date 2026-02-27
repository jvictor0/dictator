# Role Runs

## Definitions

- Role: one role execution (`architect`, `implementer`, `reviewer`, `tester`).
- Mayor: orchestration-only role that may create work-item slices/issues and invoke workflow script; Mayor is not a `run-role` target.
- Run: one deterministic invocation of one role for one work item slice.
- Work item: `/work-items/<work-item-id>/`.
- Slice: `/work-items/<work-item-id>/slices/<slice-id>/`.
- Issue: `/work-items/<work-item-id>/slices/<slice-id>/issues/issue-<n>.md`.
- Done:
  - required role artifacts exist per active slice,
  - no issue file in that slice has `Status: OPEN`.

## Canonical Slice Layout

- `SPEC.md`
- `architect.md`
- `implementer-pass-1.md`
- `reviewer-pass-1.md`
- `tester.md`
- Optional:
  - `implementer-pass-2.md`
  - `reviewer-pass-2.md`
- `issues/issue-0001.md`, `issues/issue-0002.md`, ...

Legacy work-item root artifact layout remains readable but new automation should use slice layout.

## Issue File Fields

Issue files must include:

- `Issue-ID`
- `Slice-ID`
- `Opened-By-Role` (`reviewer` or `tester`)
- `Severity` (`P0|P1|P2|P3`)
- `Status` (`OPEN|RESOLVED`)
- `Opened-At` (ISO-8601)
- `Resolved-At` (optional)
- `Resolution-Notes` (optional)

## Role State Machine

1. `architect` is allowed for initial spec creation or explicit architecture updates.
2. `implementer` pass 1 requires `SPEC.md`.
3. `reviewer` pass 1 requires `implementer-pass-1.md`.
4. `implementer` pass 2 is allowed only if:
   - open reviewer/tester issues exist, and
   - implementer pass count is less than 2.
5. `reviewer` pass 2 requires `implementer-pass-2.md`.
6. `tester` requires reviewer approval in the latest reviewer pass file.
7. Implementer pass limit is hard-capped at 2.
8. Precondition failure is a validation error and must not execute the role.

## Idempotent-Safe Reruns

- No dedupe token is required.
- Reruns are allowed only if the state machine permits the role.
- If no changes are needed, the role artifact should explicitly state no-op.
- Runner must not fabricate additional pass artifacts beyond valid transitions.

## Fresh Context Execution

- Each run invokes `codex exec --ephemeral`.
- Each run uses temporary prompt/log context and removes it after completion.
- Persistent result is only repository file changes written by the role.

## Runtime API and CLI

- REST endpoint: `POST /run-role`
- Shell entrypoint: `scripts/run-role.sh`
- Mayor bootstrap: `scripts/mayor-bootstrap.sh --work-item <id> --slice <id>`
- Workflow orchestrator: `scripts/run-workflow.py`
- API contract: `/contracts/work_item_role_runner_v1.yaml`

## HTTP Semantics

- `200`: success
- `400`: invalid request payload
- `404`: work item or slice not found
- `409`: lifecycle/state-machine validation failure
- `500`: execution/runtime failure
