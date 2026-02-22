# Slice 6 SPEC: Active target context for refinement

## Scope
- Capture frontmost app target when recording starts in macOS client.
- Build context sentence indicating active dictation target.
- Include browser website host for Chrome/Safari targets when available (best effort).
- Detect coding-agent targets by string containment (`codex` or `cursor`) and append coding-agent hint.
- Send context in `/v1/dictate` `optional_context` payload.
- Use optional context in OpenAI refinement input so transcript revision can adapt to target context.

## Out of scope
- Persistent context memory across sessions.
- Broad app-specific integrations beyond simple active app + browser host detection.
- Any contract schema change.

## Acceptance criteria
1. On successful recording start, macOS client captures active target context and retains it for stop/dictate.
2. On `/v1/dictate`, payload includes `optional_context.dictation_context` when capture succeeds.
3. For active Chrome/Safari with URL available, context sentence includes `website <host>`.
4. For app names or bundle identifiers containing `codex` or `cursor`, context sentence includes `You are talking to a coding agent.`
5. Orchestrator refiner includes optional context in model input and keeps "refined text only" output behavior.
6. Unit tests cover context helper logic and refiner context-input wiring.
