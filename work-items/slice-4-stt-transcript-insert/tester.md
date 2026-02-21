# Tester Validation

## Test matrix results
1. Build + test
- Command: `swift test && swift build`
- Location: `/Users/joyo/dictator/apps/macos-client`
- Result: Pass (`swift test` 9 tests, 0 failures)

2. Manual end-to-end transcript insertion
- Prereq: run orchestrator with `/v1/transcribe` available.
- Start app, focus a text box (for example TextEdit).
- Press Caps Lock once -> expected recording state on (`🫡 🔴`, status `Recording`).
- Speak short phrase.
- Press Caps Lock again -> expected recording state off (`🫡 ⚪`), then status `Transcribing...`, then transcript inserted.

3. Failure-mode validation
- Stop backend or set invalid `DICTATOR_API_BASE_URL`.
- Repeat start/stop flow.
- Expected: explicit status `Failed: STT request failed...` and no silent insertion.

## Pass/fail status
- Pass for build/test gates.
- Manual end-to-end confirmation required on local desktop with running orchestrator.

## Release confidence and caveats
- Confidence: Medium-high for wired flow and error handling.
- Caveat: final acceptance depends on real local STT path and desktop permissions.
