# SPEC: Timestamped orchestrator logs and visible refinement fallback reason

## Scope
- Add timestamps to orchestrator Python logs.
- Ensure refinement failures that trigger fallback are explicitly logged.
- Keep existing API behavior unchanged.

## Acceptance criteria
1. Log lines emitted by orchestrator include timestamps.
2. When refinement fails with `use_raw` fallback, log includes a warning with reason.
3. When refinement fails with `fail_closed`, log includes an error with reason.
4. Test suite remains green.
