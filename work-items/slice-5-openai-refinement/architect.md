# Architect Notes

## Design rationale
- Keep the public contract stable by implementing refinement behind existing `/v1/dictate`.
- Use dependency injection and stubbed requesters/providers for deterministic tests without real API calls.
- Surface explicit runtime validation for API key/model and explicit route-level error mapping.
- Preserve operational flexibility with fallback mode:
  - `use_raw`: degrade gracefully
  - `fail_closed`: fail request explicitly

## Key decisions
- Mac app now calls `/v1/dictate` on stop-recording and inserts `revised_text`.
- OpenAI refiner implemented via standard library HTTP request (no hard dependency on OpenAI SDK).
- Route handlers map `ValueError -> 400`, `RuntimeError -> 503` for refine/dictate/transcribe parity.

## Tradeoffs
- Direct HTTP integration is lower overhead but requires manual response parsing.
- Fallback logic in pipeline improves UX resilience but may hide upstream outages when `use_raw` mode is active.

## ADR impact
- No ADR update needed; this is slice completion within current architecture.
