# Role Handoffs

All handoff artifacts must be stored in `/work-items/<work-item-id>/slices/<slice-id>/` for new automated runs.
Legacy root-level work item artifacts remain valid for historical tasks.

## Mayor -> Architect

Allowed setup handoff actions:

- Create new slice scaffold path and starter files.
- Open or update issue files under `/work-items/<work-item-id>/issues/`.
- Trigger sequenced workflow execution via `scripts/run-workflow.py`.

## Architect -> Implementer

Required files:

- `SPEC.md`
- `architect.md`

Required contents:

- Problem statement and goals
- In/out of scope
- API/type changes
- Acceptance criteria
- Risks and fallback plan

## Implementer -> Reviewer

Required file:

- `implementer-pass-<n>.md` where `<n>` is `1` or `2`

Required contents:

- Change summary by file
- Test evidence
- Known limitations
- Rollback notes (if applicable)
- Explicit statement that spec was not changed

## Reviewer -> Implementer or Tester

Required file:

- `reviewer-pass-<n>.md` where `<n>` is `1` or `2`

Required contents:

- Findings list with severity
- Approval or required fixes
- Residual risk statement
- Issue artifacts under `/work-items/<work-item-id>/issues/issue-<n>.md` whenever issues are identified

Routing rule:

- Not approved -> Implementer next pass (up to 2 total)
- Approved -> Tester

## Tester -> Implementer or Merge

Required file:

- `tester.md`

Required contents:

- Test matrix results
- Pass/fail status
- Release confidence and caveats

Routing rule:

- Legitimate bug found -> Implementer (then Reviewer, then Tester)
- No blocking bugs -> Merge

Issue closure rule:

- Work item slice is not done until all work-item issue files in `/work-items/<work-item-id>/issues/` are marked `Status: RESOLVED`.
