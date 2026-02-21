# Implementer Pass 1

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/AudioRecorder.swift`
  - Added microphone capture service using `AVAudioRecorder` (16kHz mono PCM).
  - Added explicit recorder error modes and stop-returned audio payload.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/APIClient.swift`
  - Added transcribe request/response models.
  - Added `transcribe(_:)` request path for `/v1/transcribe`.
  - Added `emptyTranscript` API error and transcribe decode helper.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Replaced placeholder stop-insert flow with stop->transcribe->insert transcript flow.
  - Added async trigger handling guard for in-flight operations.
  - Added explicit recording/STT failure mapping to menubar status.
  - Added `DICTATOR_API_BASE_URL` runtime config support (default localhost).
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/SmokeTests.swift`
  - Added transcribe response decode shape test.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Updated behavior to Slice 4 and documented runtime base URL config.

## Test evidence
- `swift test && swift build` passed in `/Users/joyo/dictator/apps/macos-client`.
- `swift test`: 9 tests, 0 failures.

## Known limitations
- End-to-end transcript insertion still depends on local orchestrator availability and permissions.
- Audio format is fixed to a simple PCM configuration for now.

## Rollback notes
- Revert files listed above to return to Slice 3 placeholder insertion on stop.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during implementation.
