# Architect notes

## Design
- Add focused-input detector via Accessibility focused element role/editable attributes.
- Add independent key monitors for Backspace cancellation while preserving existing Caps Lock trigger path.
- Keep backend contract shape unchanged; implement empty-transcript short-circuit inside pipeline before refinement.
- Preserve no-op insertion behavior by handling empty revised text client-side.

## Tradeoffs
- Accessibility focus role detection is best effort and may vary by app.
- Backspace cancellation does not suppress native backspace behavior in host app.
