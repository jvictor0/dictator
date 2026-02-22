# SPEC: Resolve Sheaf direct-action vs refinement conflict

## Scope
- Remove conflict between "do exactly what I ask" and "return only refined text" prompt rules.
- Add explicit mode selection guidance:
  - refinement mode by default,
  - direct-action mode when user addresses Sheaf with actionable request.

## Acceptance criteria
1. Runtime prompt includes mode-selection rules.
2. Runtime prompt allows direct-action fulfillment when directly addressed by name.
3. Runtime prompt avoids fallback phrase "Please provide the transcript text..." unless transcript is empty.
4. Prompt reference markdown mirrors runtime rule.
5. Tests pass.
