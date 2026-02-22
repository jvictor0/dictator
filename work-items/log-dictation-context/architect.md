# Architect notes

## Design
- Add logging at start of `OpenAIRefiner.refine` where request context is available.
- Emit concise, single-line info logs to keep backend log scanning simple.

## Tradeoffs
- Logging context increases visibility but may expose target app/site in logs; acceptable for current debugging goal.
