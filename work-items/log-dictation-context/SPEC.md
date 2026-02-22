# SPEC: Log dictation context in orchestrator backend logs

## Scope
- Add runtime log output for `dictation_context` when refiner handles a request.
- Keep existing API behavior unchanged.

## Acceptance criteria
1. For requests with `optional_context.dictation_context`, backend logs include the string value.
2. For requests without dictation context, backend logs include explicit `<none>` marker.
3. Existing orchestrator tests pass.
