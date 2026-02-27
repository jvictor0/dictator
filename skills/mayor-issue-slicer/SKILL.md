---
name: mayor-issue-slicer
description: Create a new work-item slice from an existing work-item issue, then link the issue to that slice for role orchestration.
---

# Mayor Issue Slicer Skill

## Use when

- An issue should be handled as its own slice.
- Mayor needs a reproducible issue-to-slice workflow.

## Workflow

1. Confirm issue file exists under `work-items/<work-item-id>/issues/issue-*.md`.
2. Run:
   - `scripts/mayor-slice-from-issue.sh --work-item <id> --issue <issue-id|issue-file> [--slice <slice-id>]`
3. Verify:
   - New slice scaffold exists at `work-items/<work-item-id>/slices/<slice-id>/`.
   - Issue file contains `Slice-ID: <slice-id>`.
4. Continue orchestration with `scripts/run-workflow.py` for the new slice.

## Guardrails

- Mayor must not edit production code.
- Keep issue IDs stable; do not renumber historical issue files.
- Use explicit `--slice` when a deterministic identifier is required.
