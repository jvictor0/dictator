# Implementer Pass 2

## Trigger

Follow-up architecture concern: CLI subprocess runtime is not suitable for iOS keyboard extensions.

## Changes

- Refactored whisper execution behind `WhisperRuntime` protocol.
- Added runtime modes (`auto`, `native`, `cli`) via `DICTATOR_WHISPER_RUNTIME`.
- Added `WhisperCppNativeRuntime` placeholder (in-process target path for iOS).
- Moved CLI process execution into `WhisperCLIRuntime` (macOS-compatible fallback only).
- Updated docs to clarify iOS requires native in-process runtime.

## Files

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/WhisperCPPBridgeSTTEngine.swift`
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/WhisperCPPBridgeSTTEngineTests.swift`
- `/Users/joyo/dictator/apps/macos-client/README.md`
- `/Users/joyo/dictator/docs/architecture/ARCHITECTURE.md`

## Validation

- Command: `cd /Users/joyo/dictator/apps/macos-client && swift test`
- Result: pass (`23` tests, `0` failures)
