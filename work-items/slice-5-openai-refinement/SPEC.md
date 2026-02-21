# Slice 5 SPEC: Revise transcript with OpenAI API key

## Problem statement and goals
After STT transcription, refine text through OpenAI and insert revised text instead of raw transcript, with explicit and configurable fallback behavior.

## In scope
- Backend `OpenAIRefiner` uses OpenAI API key for transcript refinement.
- `/v1/dictate` returns revised text from refinement pipeline.
- Mac app stop-recording flow uses `/v1/dictate` and inserts `revised_text`.
- Configurable refinement fallback mode: fail closed or use raw transcript.
- Explicit failure modes for invalid key/rate limit/provider outage.
- Documentation and startup/runtime config guidance for API key.

## Out of scope
- Long-term memory or personalization beyond existing style/context fields.

## API/type changes
- No contract changes to `/Users/joyo/dictator/contracts/dictation_v1.yaml`.
- Internal behavior for `/v1/dictate` changes from raw passthrough to OpenAI-backed revised text.

## Acceptance criteria
1. Raw transcript is refined via OpenAI-backed step and revised text is inserted.
2. API key configuration path is documented and validated at startup/runtime.
3. Failure mode is explicit and test-covered (invalid key, rate limit, provider outage).
4. Tests do not require real OpenAI API key.

## Risks and fallback plan
- Risk: external API failures or auth issues.
- Fallback: configurable `REFINEMENT_FALLBACK_MODE` (`use_raw` or `fail_closed`) with explicit output/error signaling.
