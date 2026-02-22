# SPEC: Sheaf identity clause and system prompt logging

## Scope
- Update OpenAI refiner system prompt to include:
  - name declaration: "Your name is Sheaf..."
  - override clause: if user addresses by name, follow the requested action directly.
- Log the system prompt used by the refiner during refinement.
- Keep existing refinement behavior and API contract unchanged.

## Acceptance criteria
1. System prompt begins with Sheaf identity line.
2. System prompt includes the "addressed by name" override clause.
3. Refiner logs the full system prompt during request handling.
4. Prompt reference markdown reflects the same top-level clauses.
5. Orchestrator tests pass.
