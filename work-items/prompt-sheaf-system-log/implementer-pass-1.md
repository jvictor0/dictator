# Implementer pass 1

## Changes made
- Added Sheaf identity + addressed-by-name clause at top of runtime instructions in `services/orchestrator/app/services/llm/openai_refiner.py`.
- Added runtime logging of full system prompt in `OpenAIRefiner.refine`.
- Updated `prompts/refine_transcript.md` with matching top clauses.
- Extended unit test assertion coverage for new instruction clauses.

## Constraints followed
- No contract or API schema changes.
- Implementer did not change `SPEC.md` after writing it.
