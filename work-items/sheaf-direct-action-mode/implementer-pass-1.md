# Implementer pass 1

## Changes made
- Added `Mode selection rule` section to runtime instructions in `services/orchestrator/app/services/llm/openai_refiner.py`.
- Updated output rule to return final text for selected mode.
- Updated `prompts/refine_transcript.md` with matching mode-selection guidance.
- Extended test assertions in `services/orchestrator/tests/test_openai_refiner.py`.
- Ran orchestrator tests.

## Constraints followed
- No contract/API schema changes.
