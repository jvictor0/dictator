# Architect Notes

## Design rationale
- Use `AVAudioRecorder` with linear PCM at 16kHz mono for straightforward payload generation.
- Preserve Slice 3 toggle model:
  - first Caps Lock starts recording
  - second Caps Lock stops recording and initiates STT request
- Use `/v1/transcribe` endpoint directly to keep Slice 4 independent of LLM refinement.
- Reuse existing insertion path (`ClipboardInserter`) to place transcript in focused target.

## Key flow
1. Start: request mic permission and begin audio recording.
2. Stop: read captured audio bytes and POST to `/v1/transcribe`.
3. Success: insert `raw_transcript`.
4. Failure: show explicit menu status (`Failed: ...`) and do not silently insert anything.

## Tradeoffs
- `AVAudioRecorder` file-based capture is simpler than stream capture and sufficient for slice scope.
- Concurrency is serialized with an in-flight trigger guard to avoid overlapping stop/transcribe operations.

## ADR impact
- No ADR update required for this incremental slice.
