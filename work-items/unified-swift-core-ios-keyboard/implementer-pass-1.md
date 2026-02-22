# Implementer Pass 1

## Summary

Implemented unified Swift core migration for macOS path and added iOS wrapper scaffolding.

## Code changes

- Added shared Swift target and module:
  - `apps/macos-client/Sources/DictatorCore/Contracts.swift`
  - `apps/macos-client/Sources/DictatorCore/Errors.swift`
  - `apps/macos-client/Sources/DictatorCore/Interfaces.swift`
  - `apps/macos-client/Sources/DictatorCore/PipelineOrchestrator.swift`
  - `apps/macos-client/Sources/DictatorCore/OpenAIRefinementEngine.swift`
  - `apps/macos-client/Sources/DictatorCore/SpeechFrameworkSTTEngine.swift`
- Updated package wiring:
  - `apps/macos-client/Package.swift`
- Migrated app runtime to in-process core pipeline:
  - `apps/macos-client/Sources/DictatorApp/main.swift`
  - `apps/macos-client/Sources/DictatorApp/APIClient.swift` (compat adapter to core)
- Added key storage adapter:
  - `apps/macos-client/Sources/DictatorApp/KeychainSecretStore.swift`
- Added menubar API key actions:
  - `apps/macos-client/Sources/DictatorApp/MenuBarController.swift`
- Removed Python backend manager source:
  - deleted `apps/macos-client/Sources/DictatorApp/BackendServiceManager.swift`
- Added iOS wrapper scaffold:
  - `apps/ios-keyboard/README.md`
  - `apps/ios-keyboard/HostApp/SettingsViewModel.swift`
  - `apps/ios-keyboard/KeyboardExtension/KeyboardPipelineController.swift`
- Added core tests:
  - `apps/macos-client/Tests/DictatorCoreTests/PipelineTests.swift`
- Updated docs/build commands:
  - `README.md`
  - `apps/macos-client/README.md`
  - `docs/architecture/ARCHITECTURE.md`
  - `docs/testing/TEST_STRATEGY.md`
  - `docs/product/ROADMAP.md`
  - `Makefile`

## Notes

- Refinement now requires user-pasted key in Keychain and fails closed when missing/invalid/network unavailable.
- STT interface includes whisper.cpp placeholder; current runtime engine is Speech framework.
