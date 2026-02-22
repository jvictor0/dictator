# Architect notes

## Diagnosis
- Prior prompt had contradictory constraints:
  - direct execution when addressed by name,
  - return only refined transcript.
- In conflict, model often stayed in refinement mode, causing wake-command requests to remain unexecuted.

## Design
- Introduce explicit mode switch hierarchy.
- Keep single output-channel semantics (still one text output) while allowing requested content generation in direct-action mode.
