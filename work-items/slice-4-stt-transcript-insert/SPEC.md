# Slice 4 SPEC: Send audio to Whisper and insert transcript

## Problem statement and goals
Replace Slice 3 placeholder insertion with real STT flow: when recording stops, send captured audio to the transcribe endpoint and insert returned transcript text.

## In scope
- Capture microphone audio while recording is active.
- On stop-recording, send captured audio to STT endpoint (`/v1/transcribe`).
- Receive transcript text and insert it at current cursor target.
- Keep explicit failure messaging for STT errors and insertion errors.

## Out of scope
- LLM refinement
- Context-aware rewriting

## API/type changes
- No contract changes in `/Users/joyo/dictator/contracts/dictation_v1.yaml`.
- Client adds `TranscribeRequest`/`TranscribeResponse` models and `/v1/transcribe` call support.

## Acceptance criteria
1. `swift build` passes in `/Users/joyo/dictator/apps/macos-client`.
2. `swift test` passes in `/Users/joyo/dictator/apps/macos-client`.
3. After stop-recording, transcript is returned and inserted into active text box.
4. If STT fails, user receives clear failure signal and no silent drop.
5. End-to-end flow works with configured Whisper path.

## Risks and fallback plan
- Risk: audio encoding/format mismatch between client capture and provider.
- Risk: STT latency and request failures.
- Fallback: surface explicit status errors and trace logs; keep app state consistent and insertion skipped on STT failure.
