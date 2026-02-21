# Architect Notes

## Design rationale
- Introduce a focused `CapsLockTriggerController` to isolate trigger registration from UI wiring.
- Keep a deterministic trigger predicate (`shouldTrigger`) to make key filtering testable.
- Upgrade `ClipboardInserter` to a real fallback insertion path: write clipboard then synthesize `Cmd+V`.
- Keep user-facing failure explicit through menubar state text (`Status: Failed: ...`).

## Tradeoffs
- True end-to-end Caps Lock + paste behavior depends on macOS permission state and foreground app behavior, so automated testing remains partial.
- Clipboard restoration is not implemented in Slice 2 to avoid extra complexity; this is acceptable for scope but is a UX caveat.

## Interfaces and behavior
- `CapsLockTriggerController.start()` requests accessibility trust and arms global/local flagsChanged monitors.
- `ClipboardInserter.insert(_:)` now returns `Result<Void, InsertError>` with explicit failure reasons.
- `MenuBarController` includes a disabled status item to communicate runtime state/failures.

## ADR impact
- No ADR change needed; this is an incremental slice implementation inside current architecture.
