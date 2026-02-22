# Implementer pass 3

## User-directed rollback
- Removed focused text-input gate per user request.
- Recording now always starts on Caps Lock (subject to microphone/backend availability), regardless of focused control.

## Code change
- Deleted focus guard block in `apps/macos-client/Sources/DictatorApp/main.swift` within `startRecording`.

## Notes
- Backspace cancel behavior and empty-transcript short-circuit remain active.
