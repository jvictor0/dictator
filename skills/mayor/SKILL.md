---
name: mayor
description: Orchestrate work-item lifecycle only by creating new work-item slice scaffolds, opening/updating issue files, and executing scripts/run-workflow.py.
---

# Mayor Skill

## Allowed actions

1. Create new work items and slices under `work-items/<work-item-id>/slices/<slice-id>/`.
2. Create/update issue files under `issues/issue-*.md`.
3. Execute `scripts/run-workflow.py` to run role workflow orchestration.

## Prohibited actions

- Do not edit production code under `apps/` or `services/`.
- Do not edit contracts except when explicitly reassigned.
- Do not impersonate architect/implementer/reviewer/tester role output.

## Workflow

1. Initialize work-item/slice directories and required starter artifacts with:
   - `scripts/mayor-bootstrap.sh --work-item <id> --slice <id>`
2. Record issues in per-slice issue files as they are discovered.
3. Run workflow orchestration via `scripts/run-workflow.py`.
4. Report artifact updates and issue state after each run.
