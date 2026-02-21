# Implementer Pass 1

## Change summary by file
- `/Users/joyo/dictator/services/orchestrator/app/services/stt/whisper_local.py`
  - Replaced hardcoded mock transcript with real Whisper transcription flow.
  - Added base64 decode, temp audio file handling, language selection, segment mapping, confidence/duration derivation.
  - Added explicit errors for invalid base64 and missing Whisper dependency.
- `/Users/joyo/dictator/services/orchestrator/app/services/pipeline.py`
  - Added dependency injection hooks for STT/LLM providers to keep tests deterministic.
- `/Users/joyo/dictator/services/orchestrator/tests/test_pipeline.py`
  - Switched to fake providers via DI so pipeline tests remain stable and do not require live Whisper inference.
- `/Users/joyo/dictator/services/orchestrator/tests/test_whisper_local.py`
  - Added provider tests for response mapping and invalid-base64 failure mode.
- `/Users/joyo/dictator/services/orchestrator/pyproject.toml`
  - Added `openai-whisper` runtime dependency.
- `/Users/joyo/dictator/services/orchestrator/README.md`
  - Documented real Whisper usage, ffmpeg dependency, and first-run model download behavior.

## Test evidence
- Command: `cd /Users/joyo/dictator/services/orchestrator && .venv/bin/python -m pytest -q`
- Result: `7 passed in 0.10s`

## Known limitations
- Real Whisper requires `openai-whisper` install and `ffmpeg` on PATH.
- First use may download model files, causing initial latency.

## Rollback notes
- Revert files above to restore static mock transcript behavior.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during implementation.
