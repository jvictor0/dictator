# Implementer pass 1

## Summary
Added explicit `Cloud Model` and `Local Model` runtime configurations, migrated runtime config schema to include both model fields, and ensured cloud mode uses `cloud_model`.

## Files changed
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfig.swift`
  - Added `cloudModel` + `localModel` fields.
  - Added legacy `model` decode compatibility.
  - Kept computed `model` for active mode.
  - Extended `RuntimeConfigPatch` with `cloudModel` and `localModel`.
  - Updated patch resolution logic to target correct model per mode.

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/LLMRuntimeConfiguration.swift`
  - Runtime override now maps:
    - cloud mode -> `openAIModel = cloudModel`
    - local mode -> `ollamaModel = localModel`

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfiguration.swift`
  - Extended `RuntimeModelConfiguration` with per-target model updates (`.cloud` / `.local`).
  - Added model options source routing (`.ollama` / `.openAI`).

- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Runtime configuration manager now creates:
    - `Cloud Model`
    - `Use Cloud`
    - `Local Model`

- `/Users/joyo/dictator/apps/macos-client/Config/runtime-config.safe`
- `/Users/joyo/dictator/apps/macos-client/Config/runtime-config.json`
  - Migrated to `cloud_model` / `local_model` defaults.

- Tests updated:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/LLMRuntimeConfigurationTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigProviderTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigurationManagerTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`

## Validation
- Command: `swift test`
- Workdir: `/Users/joyo/dictator/apps/macos-client`
- Result: pass (`81` tests, `0` failures)

## Spec conformance
- Two new model configs added.
- Safe defaults now include separate cloud/local models.
- Cloud mode deterministically uses `Cloud Model`.
