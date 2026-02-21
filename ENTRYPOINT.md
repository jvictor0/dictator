# Dictator Entrypoint

Use this file as the first instruction source for any new implementation chat.

## Primary instruction

Read and follow these files in order:

1. `/Users/joyo/dictator/AGENTS.md`
2. `/Users/joyo/dictator/docs/governance/BYLAWS.md`
3. `/Users/joyo/dictator/docs/governance/WORKFLOWS.md`
4. `/Users/joyo/dictator/docs/governance/ROLE_HANDOFFS.md`
5. `/Users/joyo/dictator/docs/product/ROADMAP.md`

## Task execution rule

When user asks to implement a slice:

1. Find slice scope and acceptance criteria in `/Users/joyo/dictator/docs/product/ROADMAP.md`.
2. Create work item folder: `/Users/joyo/dictator/work-items/slice-<n>-<short-name>/`.
3. Run required roles in order:
   - Architect -> create `SPEC.md` and `architect.md`
   - Implementer -> `implementer-pass-1.md` (and pass 2 only if needed)
   - Reviewer -> `reviewer-pass-1.md` (and pass 2 only if needed)
   - Tester -> `tester.md`
4. Enforce policy constraints:
   - Implementer cannot change `SPEC.md`
   - Implementer max passes: 2
   - If unresolved after pass 2, record blocker reason and stop
   - Tester cannot change production code
   - Tester may route legitimate bugs back to implementer, then reviewer, then tester
5. Update code/tests/docs needed by the slice.
6. Verify acceptance criteria with evidence in `tester.md`.
7. Commit only when tester passes and gates are satisfied.

## Preferred commit style

- One commit per slice when practical.
- Commit message format: `Slice <n>: <short description>`.

## Minimal user prompt pattern

`Read /Users/joyo/dictator/ENTRYPOINT.md and implement Slice <n>.`
