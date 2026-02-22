# Implementer pass 1

## Changes made
- Updated runtime OpenAI instructions in `services/orchestrator/app/services/llm/openai_refiner.py`.
- Added explicit intent-preserving, transcription-correction, and change-of-mind conflict rules.
- Removed "post processing" phrasing from prompt context.
- Updated `prompts/refine_transcript.md` to match the intended system prompt language.
- Added unit assertion coverage in `services/orchestrator/tests/test_openai_refiner.py` for the new instruction content.

## Constraints followed
- No changes to `SPEC.md` during implementation.
- No contract changes.
