---
name: mayor
description: Orchestrate work-item lifecycle only by creating new work-item slice scaffolds, opening/updating work-item issue files, creating slices from issues, and executing scripts/run-workflow.py.
---

# Mayor Skill

## Allowed actions

1. Create new work items and slices under `work-items/<work-item-id>/slices/<slice-id>/`.
2. Create/update issue files under `work-items/<work-item-id>/issues/issue-*.md`.
3. Execute `scripts/run-workflow.py` to run role workflow orchestration.
4. Create a new slice directly from an issue with `scripts/mayor-slice-from-issue.sh`.

## Prohibited actions

- Do not edit production code under `apps/` or `services/`.
- Do not edit contracts except when explicitly reassigned.
- Do not impersonate architect/implementer/reviewer/tester role output.

## Workflow

1. Initialize work-item/slice directories and required starter artifacts with:
   - `scripts/mayor-bootstrap.sh --work-item <id> --slice <id>`
2. Record issues in work-item issue files as they are discovered.
3. When an issue needs isolated implementation, generate a slice from it:
   - `scripts/mayor-slice-from-issue.sh --work-item <id> --issue issue-0001`
4. Run workflow orchestration via `scripts/run-workflow.py`.
5. Report artifact updates and issue state after each run.
