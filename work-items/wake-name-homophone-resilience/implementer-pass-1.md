# Implementer pass 1

## Changes made
- Added `Wake-name normalization rule` to runtime instructions in `services/orchestrator/app/services/llm/openai_refiner.py`.
- Updated `prompts/refine_transcript.md` with matching guidance.
- Extended tests in `services/orchestrator/tests/test_openai_refiner.py` to assert new rule text.

## Constraints followed
- No contract/schema changes.
