# Implementer Pass 1

## Summary

Implemented a real `WhisperCPPBridgeSTTEngine` using `whisper-cli` process invocation + JSON mapping and switched macOS runtime default STT to whisper bridge.

## Changes

- Added whisper bridge engine:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/WhisperCPPBridgeSTTEngine.swift`
- Kept Speech framework engine as non-default fallback implementation:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/SpeechFrameworkSTTEngine.swift`
- Switched runtime pipeline STT selection to whisper bridge:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
- Added whisper bridge test coverage:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/WhisperCPPBridgeSTTEngineTests.swift`
- Added runtime configuration docs:
  - `/Users/joyo/dictator/apps/macos-client/README.md`

## Validation

- Command: `cd /Users/joyo/dictator/apps/macos-client && swift test`
- Result: pass (`22` tests, `0` failures)

## Notes

- Bridge expects `whisper-cli` and a model file at runtime (`DICTATOR_WHISPER_CPP_BIN`, `DICTATOR_WHISPER_MODEL`).
- Missing/broken whisper runtime surfaces explicit `DictatorError.sttFailed(...)`.
