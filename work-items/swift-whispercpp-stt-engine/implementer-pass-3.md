# Implementer Pass 3

## Trigger

User decision: remove CLI mode entirely and keep Whisper runtime native-only.

## Changes

- Removed `RuntimeMode` and CLI runtime selection from `WhisperCPPBridgeSTTEngine`.
- Removed CLI-related configuration (`DICTATOR_WHISPER_RUNTIME`, `DICTATOR_WHISPER_CPP_BIN`).
- Removed `WhisperCLIRuntime` implementation.
- `WhisperCPPBridgeSTTEngine` now always uses `WhisperCppNativeRuntime` unless a test runtime is injected.
- Updated docs to reflect native-only runtime model.

## Files

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/WhisperCPPBridgeSTTEngine.swift`
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/WhisperCPPBridgeSTTEngineTests.swift`
- `/Users/joyo/dictator/apps/macos-client/README.md`
- `/Users/joyo/dictator/docs/architecture/ARCHITECTURE.md`

## Validation

- Command: `cd /Users/joyo/dictator/apps/macos-client && swift test`
- Result: pass (`23` tests, `0` failures)
