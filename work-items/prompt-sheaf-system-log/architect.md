# Architect notes

## Design
- Place new clauses at the top of `OpenAIRefiner.INSTRUCTIONS` to satisfy ordering requirement.
- Use Python module logger (`logging.getLogger(__name__)`) and emit prompt text once per refinement call at info level.
- Preserve request/response schema and provider flow.

## Tradeoffs
- Logging full prompt each call increases log volume but gives transparent runtime traceability.
