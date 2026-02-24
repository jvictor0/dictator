# Implementer pass 1

## Summary
Implemented runtime configuration class abstractions with overridable list/set methods, safe-default startup loading, in-memory set behavior for future dictation calls, and reset-by-iteration over configuration objects.

## Code changes
- Added new runtime configuration model and manager:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfiguration.swift`
  - Includes:
    - `RuntimeConfigurationValue`
    - `RuntimeConfigurationSnapshot`
    - abstract-like `RuntimeConfiguration` base class (`getOptions`, `set`)
    - `RuntimeModelConfiguration` (Ollama `/api/tags` options)
    - `RuntimeBooleanConfiguration` (`use_cloud` boolean options)
    - `RuntimeConfigurationManager` (list/set/reset)

- Updated runtime provider for startup defaults and memory-only mutation:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfig.swift`
  - Added:
    - safe-default store support in initializer
    - `startupDefaultConfig()` accessor
    - `applyInMemoryPatch(...)`

- Updated voice config set path to mutate in-memory runtime config:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/VoiceConfigInteractionOrchestrator.swift`
  - `applyPatch` -> `applyInMemoryPatch`

- Updated app reset action to iterate configs and call set-to-default:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Added runtime configuration manager initialization on startup.
  - Replaced safe reset implementation to call `manager.resetToDefaults()`.

## Tests updated/added
- Updated:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigProviderTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/VoiceConfigInteractionOrchestratorTests.swift`
- Added:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigurationManagerTests.swift`

## Validation
- Command: `swift test` (workdir: `/Users/joyo/dictator/apps/macos-client`)
- Result: pass (`79` tests, `0` failures)

## Spec conformance
- Required class properties/methods implemented.
- Model list call uses Ollama model list endpoint.
- Set behavior updates runtime config in memory for future dictation.
- Startup defaults read from safe config.
- Reset flow iterates configuration list and applies defaults via `set`.
