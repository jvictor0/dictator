# Reviewer pass 1

## Findings
- No P0/P1 findings.

## Notes
- Eviction logic is FIFO by insertion order and enforces `totalTrackedBytes <= maxBytes`.
- Mode classification maps selected-text flows to `text_replacement`, exact raw/revised match to `raw_dictation`, and all other cases to `revision`.
- Overlay keyboard handling for Interactions tab is limited to up/down and does not interfere with existing tab routing.
- Runtime config extension (`interactions_buffer_bytes`) is backward-compatible for older JSON files via decode default.
