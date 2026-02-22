# Architect Notes

## Design
- Use `NSPasteboard.changeCount` as freshness signal for synthetic copy capture.
- Capture flow:
1. Record prior `changeCount`.
2. Issue synthetic `Cmd+C`.
3. Poll briefly for `changeCount` advancement.
4. Accept clipboard text only if count advanced, then run normalization.
5. Restore prior clipboard snapshot.

## Rationale
- Prevents stale clipboard reuse when copy action fails or selection is absent.
- Keeps behavior deterministic and cheap without adding new platform dependencies.

## Risks
- Some apps may update clipboard slower than polling timeout; this degrades to `nil` selected text (safe default).
