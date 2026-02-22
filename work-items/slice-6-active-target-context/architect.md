# Architect notes

## Design summary
- Capture context at recording start (not stop) to preserve where dictation began.
- Keep context transport on existing `optional_context` dictionary to avoid contract changes.
- Generate a human-readable `dictation_context` sentence in macOS client for direct prompt use.
- Keep coding-agent detection intentionally simple (`codex`/`cursor` case-insensitive containment).
- Refiner composes an input preamble from optional context and raw transcript.

## Tradeoffs
- Browser URL detection via AppleScript is best effort and can fail silently due permissions; app still sends app-only context.
- Context is injected as input block rather than per-request instruction mutation for minimal API plumbing change.

## Compatibility
- No breaking change to `/contracts/dictation_v1.yaml`.
