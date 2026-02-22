# Architect notes

## Architecture decisions
- Keep API contract stable; route selected-text feature through existing `optional_context` map.
- Preserve single `/v1/dictate` endpoint and pipeline.
- Implement selection detection client-side at recording start, aligned with existing context capture timing.

## Data flow
1. User presses Caps Lock -> recording starts.
2. Client captures:
   - active target context (`active_app`, `active_site`, etc.),
   - selected text via clipboard copy simulation (best effort).
3. User stops recording -> audio sent to `/v1/dictate` with optional context.
4. STT transcript produced.
5. Refiner mode selection:
   - if `selected_text` present: transform selected text using transcript request,
   - else: standard transcript refinement.
6. Revised text inserted at cursor via existing paste path.

## Risks and mitigations
- Selection capture reliability varies by app: fallback is no-selection mode.
- Clipboard perturbation risk: snapshot/restore is retained to preserve prior clipboard state.
- Oversized selection payloads: normalized/truncated on client to bounded size.
