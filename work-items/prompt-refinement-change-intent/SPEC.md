# SPEC: Refine system prompt for transcription correction and change-of-mind intent

## Scope
Update the OpenAI refinement instruction so the model:
- treats input as potentially imperfect Whisper-derived voice-to-text,
- rewrites toward intended meaning,
- resolves speaker self-corrections by prioritizing final intent,
- returns only refined text.

Out of scope:
- API contract changes,
- new request/response fields,
- pipeline behavior outside instruction text.

## Acceptance criteria
1. Runtime OpenAI instruction text includes explicit guidance for transcription-error correction and intent-preserving rewrite.
2. Instruction text includes explicit conflict-resolution handling for revisions like "actually/instead/on second thought" with final intent priority.
3. Runtime instruction text removes mention of "post processing" and uses "Whisper + refinement" wording.
4. Prompt reference document is aligned to runtime instruction intent.
5. Existing refinement tests pass; coverage includes assertion for updated instruction content.
