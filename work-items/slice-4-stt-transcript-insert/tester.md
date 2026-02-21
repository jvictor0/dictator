# Tester Validation

## Test matrix results
1. Build + test
- Command: `swift test && swift build`
- Location: `/Users/joyo/dictator/apps/macos-client`
- Result: Pass (`swift test` 9 tests, 0 failures)

2. Pass-1 issue and pass-2 re-validation
- Reported issue: app required manually starting backend service.
- Pass-2 fix: app-managed backend lifecycle (setup/start/health-check/stop).
- Additional hardening: avoids repeated long reinstall attempts when dependency install previously failed.
- Re-validation expectation on launch:
  - status transitions to `Starting backend...`
  - then `Ready (Caps Lock toggles recording)` when backend is healthy
  - no manual backend command required.

3. Manual end-to-end transcript insertion
- Start app only (do not manually start backend).
- Focus text box (for example TextEdit).
- Press Caps Lock once -> `🫡 🔴`, status `Recording`.
- Speak short phrase.
- Press Caps Lock again -> `🫡 ⚪`, status `Transcribing...`, transcript inserted.

4. Failure-mode validation
- If backend setup fails (Python/pip/dependency/network issue), expect explicit status `Failed: Backend setup failed: ...`.
- On failed backend, pressing Caps Lock should not silently proceed; expect explicit `Failed: Backend unavailable`.
- Relaunch shortly after failure should fail fast (no long reinstall loop) while within cooldown window.

## Pass/fail status
- Pass for build/test gates.
- Manual desktop sign-off required for full wrapper-managed startup and transcript insertion confirmation.

## Release confidence and caveats
- Confidence: High for app-side orchestration logic and failure visibility.
- Caveat: first-run dependency installation still depends on host Python/pip and network/package availability.
