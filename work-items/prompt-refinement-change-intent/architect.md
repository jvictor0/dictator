# Architect notes

## Design
- Keep prompt logic in-process via `OpenAIRefiner.INSTRUCTIONS` to avoid changing control flow.
- Maintain existing API contract (`revised_text`, `edit_summary`, `uncertainty_flags`) with no schema change.
- Keep `prompts/refine_transcript.md` as human-readable canonical guidance aligned with runtime instructions.

## Tradeoffs
- Embedding the instruction string in code avoids introducing file I/O failure modes.
- Exact parity between markdown prompt file and runtime string is maintained manually.

## Role note
No role skipped. Architect scope limited to instruction-shape decisions only.
