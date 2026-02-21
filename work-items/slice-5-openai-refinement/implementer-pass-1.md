# Implementer Pass 1

## Change summary by file
- `/Users/joyo/dictator/services/orchestrator/app/services/llm/openai_refiner.py`
  - Replaced placeholder capitalization logic with real OpenAI Responses API call.
  - Added runtime config validation for `OPENAI_API_KEY` and `OPENAI_MODEL`.
  - Added explicit error mapping for auth/rate-limit/provider failures.
  - Added requester injection to enable tests with no real API key.
- `/Users/joyo/dictator/services/orchestrator/app/services/pipeline.py`
  - Added configurable fallback behavior for refinement failures (`use_raw` vs `fail_closed`).
- `/Users/joyo/dictator/services/orchestrator/app/core/config.py`
  - Added `refinement_fallback_mode` setting.
- `/Users/joyo/dictator/services/orchestrator/app/api/routes.py`
  - Added explicit `ValueError`/`RuntimeError` handling for `/v1/refine` and `/v1/dictate`.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Switched stop-recording flow from `/v1/transcribe` to `/v1/dictate`.
  - Inserts `revised_text` and updates user-visible status/error messaging.
- `/Users/joyo/dictator/services/orchestrator/tests/test_openai_refiner.py`
  - Added tests for key validation, auth/rate-limit failures, and successful revised text path without real API.
- `/Users/joyo/dictator/services/orchestrator/tests/test_pipeline.py`
  - Added fallback mode tests (`use_raw` and `fail_closed`).
- `/Users/joyo/dictator/services/orchestrator/tests/test_routes_transcribe.py`
  - Expanded route-level error mapping and success-shape tests for refine/dictate routes.
- `/Users/joyo/dictator/.env.example`
  - Added `REFINEMENT_FALLBACK_MODE`.
- `/Users/joyo/dictator/services/orchestrator/README.md`
  - Documented OpenAI API key/configuration path and fallback modes.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Updated behavior to Slice 5 (`/v1/dictate`, revised text insertion).

## Test evidence
- `cd /Users/joyo/dictator/services/orchestrator && .venv/bin/python -m pytest -q` -> `20 passed`
- `cd /Users/joyo/dictator/apps/macos-client && swift test && swift build` -> pass

## Known limitations
- Real refinement depends on outbound connectivity to OpenAI.
- `use_raw` fallback may mask transient provider issues while preserving UX continuity.

## Rollback notes
- Revert files above to restore pre-Slice-5 behavior.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during implementation.
