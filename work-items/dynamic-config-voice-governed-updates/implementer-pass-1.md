# Implementer pass 1

## Summary
Implemented JSON-backed dynamic runtime config with strict LLM-driven patch updates and immediate runtime effect, where `runtime-config.json` overrides `.env` for mutable fields. Added provider-side model availability checks with closest-match resolution before persisting updates.

## Changes by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfig.swift`
  - Added `RuntimeConfigFile`, `RuntimeConfigPatch`, `RuntimeConfigStore`, and actor `RuntimeConfigProvider`.
  - Implements load-or-create behavior, atomic JSON writes, patch application, and in-memory reload.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/LLMRuntimeConfiguration.swift`
  - Added merge path `fromEnvironment(..., runtimeOverride:)`.
  - Runtime JSON now overrides `.env` for `model` and `use_cloud` semantics.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/VoiceConfigDecision.swift`
  - Added strict decision parser for LLM output (`no_change` or `update` only).
  - Added `OpenAIVoiceConfigDecisionEngine` and `OllamaVoiceConfigDecisionEngine`.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/VoiceConfigInteractionOrchestrator.swift`
  - Added high-level API orchestrator for voice-config interaction:
    - STT transcript capture
    - LLM decision
    - model availability check + closest-match model resolution
    - validated patch apply to JSON only
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/ModelAvailabilityChecker.swift`
  - Added provider-specific model catalog checks:
    - Ollama: `GET /api/tags`
    - OpenAI: `GET /v1/models`
  - Added closest-match resolver (exact match first, then similarity scoring).
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/RuntimeConfigRefinementEngine.swift`
  - Added runtime-provider-backed refinement engine so config changes affect next requests immediately.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/Interfaces.swift`
  - Extended `DictatorCoreClient` with `interactForRuntimeConfig(...)`.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/PipelineOrchestrator.swift`
  - Wired optional `VoiceConfigInteractionOrchestrator` and exposed runtime-config interaction API.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/Errors.swift`
  - Added config-interaction error cases.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Wired `RuntimeConfigProvider` + `RuntimeConfigRefinementEngine`.
  - App now reads effective runtime config through provider (not stale env snapshot) for refinement routing.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/APIClient.swift`
  - Added `interactForRuntimeConfig(...)` adapter method.
- Added tests:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigProviderTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/VoiceConfigDecisionParserTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/VoiceConfigInteractionOrchestratorTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/ModelAvailabilityCheckerTests.swift`

## Validation evidence
- Command: `swift test` (workdir: `/Users/joyo/dictator/apps/macos-client`)
- Result: pass (`66` tests, `0` failures)

## Spec conformance statement
- Spec scope was not changed during implementation.
- `.env` is bootstrap/default input; runtime JSON overrides mutable fields (`model`, `use_cloud`).
- LLM output is treated as untrusted and only accepted as strict allowlisted patch keys.
- Update path writes only the runtime JSON file and applies effects immediately in runtime provider state.

## Known limitations
- No dedicated menu/UX trigger was added yet for invoking runtime-config voice interaction; API exists and is callable through `APIClient`/`DictatorCoreClient`.
- `runtime-config.json` includes version/timestamp metadata; version is currently fixed at `1`.

## Rollback notes
- Revert files listed in this pass to return to env-only runtime behavior.
