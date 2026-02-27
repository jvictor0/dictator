# Workflows

## Primary lifecycle

0. Mayor may create the work-item slice scaffold and initialize issue tracking files.
1. Architect defines scope, interfaces, risks, and acceptance criteria in slice `SPEC.md`.
2. Implementer delivers pass 1 against approved spec.
3. Reviewer evaluates correctness, risk, and contract consistency.
4. If reviewer finds issues, implementer executes pass 2.
5. Reviewer re-checks pass 2.
6. If still not approved after pass 2, implementer records blocker and stops.
7. Tester runs validation matrix only on reviewer-approved changes.
8. If tester finds a legitimate bug, route back to implementer, then reviewer, then tester.

Canonical automation entrypoint for a single role run:

- `POST /run-role` (see `/contracts/work_item_role_runner_v1.yaml`)
- `scripts/run-role.sh --work-item <id> --slice <id> --role <role>`
- `scripts/run-workflow.py --work-item <id> --slice <id>` for sequenced workflow execution with artifact reporting
- `scripts/mayor-bootstrap.sh --work-item <id> --slice <id>` for Mayor scaffold initialization

## Pass limits and stop condition

- Implementer pass limit per work item: 2.
- Implementer cannot alter spec during passes.
- On unresolved issues after pass 2, create a blocker note in the work item folder and stop.
- A slice is not done while any issue file in `issues/` has `Status: OPEN`.

## Fast path

Allowed only for trivial documentation-only changes. Requires reviewer acknowledgment of fast-path eligibility.

## Incident workflow

1. Reproduce with minimal failing case.
2. Add failing test where possible.
3. Patch with smallest safe fix.
4. Run focused regression suite.
5. Document root cause and prevention action.
