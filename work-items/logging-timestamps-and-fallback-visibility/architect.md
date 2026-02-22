# Architect notes

## Design
- Configure logging in `app.main` via `logging.basicConfig(..., force=True)` to ensure formatter includes timestamp and applies consistently.
- Add `pipeline` logger statements inside fallback/error branches so silent fallback is visible in backend logs.

## Tradeoffs
- `force=True` overrides existing logging config, prioritizing consistent timestamped output over uvicorn default formatting.
