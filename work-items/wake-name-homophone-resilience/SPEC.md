# SPEC: Improve wake-name resilience for Sheaf homophones

## Scope
- Update refinement system prompt to better normalize Sheaf-like wake-name misrecognitions.
- Include explicit examples (`chief`, `sheef`, `sheath`) with guardrail for literal phrases.
- Keep existing API contract and flow unchanged.

## Acceptance criteria
1. Runtime instructions include wake-name normalization section.
2. Prompt guidance explicitly handles likely homophones and avoids rewriting literal phrases like "chief of staff".
3. Prompt reference markdown mirrors the new rule.
4. Tests pass.
