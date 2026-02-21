# Architect Notes

## Design rationale
- Reuse `RecordingController` as the single source of truth for recording state.
- Keep Caps Lock trigger callback minimal: toggle state first, then branch behavior by resulting state.
- Active visual indicator is implemented in `MenuBarController` as an attributed title that colors the indicator glyph while recording.
- Guard state consistency by deduplicating near-simultaneous duplicate trigger events across global/local monitors.

## Key decisions
- Insert text only on transition `recording=true -> recording=false`.
- Keep existing explicit insertion failure messaging and trace logging.
- Preserve clipboard restore behavior from Slice 2.

## Tradeoffs
- Indicator color uses attributed text rather than image asset; simple and sufficient for slice scope.
- Debounce interval is heuristic-based and tuned for duplicate monitor callbacks, not for generalized rate limiting.

## ADR impact
- No ADR update needed for this incremental behavior slice.
