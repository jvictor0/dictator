# SPEC: Replace mock STT text with real Whisper transcription

## Problem statement and goals
Current STT path returns static placeholder text (`mock transcript from local whisper`). Replace this with real local Whisper transcription while keeping contract shape stable.

## In scope
- Implement real transcription logic in `whisper_local` provider.
- Decode `audio_b64` payload and transcribe captured audio.
- Preserve `/v1/transcribe` response contract fields.
- Keep pipeline tests stable via dependency injection/mocking where needed.
- Add/adjust tests for provider mapping and error paths.

## Out of scope
- LLM refinement behavior changes
- New API endpoints
- Provider switching UI

## API/type changes
- No changes to `/Users/joyo/dictator/contracts/dictation_v1.yaml`.
- Internal provider behavior changes from static text to dynamic transcription.

## Acceptance criteria
1. `/v1/transcribe` no longer returns hardcoded placeholder transcript.
2. Existing orchestrator pipeline tests pass.
3. New tests validate provider output mapping and invalid base64 handling.
4. Contract compatibility remains unchanged.

## Risks and fallback plan
- Risk: local environment missing Whisper dependency or ffmpeg.
- Fallback: raise explicit runtime error for missing dependency so failure is visible (not silent placeholder output).
