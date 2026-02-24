# Implementer pass 1

## Changes made
- Created versioned prompt directory and seeded current prompt text:
  - `prompts/system-prompts/intent_refiner_v1.md`
- Added `SystemPromptCatalog` for system prompt discovery/loading/fallback:
  - `apps/macos-client/Sources/DictatorCore/SystemPromptCatalog.swift`
- Extended runtime config model and patching with `system_prompt`:
  - `apps/macos-client/Sources/DictatorCore/RuntimeConfig.swift`
  - `apps/macos-client/Config/runtime-config.json`
  - `apps/macos-client/Config/runtime-config.safe`
- Extended effective runtime configuration with selected prompt file:
  - `apps/macos-client/Sources/DictatorCore/LLMRuntimeConfiguration.swift`
- Added runtime configuration type for selectable prompt files:
  - `RuntimeSystemPromptConfiguration` in `apps/macos-client/Sources/DictatorCore/RuntimeConfiguration.swift`
- Wired runtime configuration manager to include "System Prompt":
  - `apps/macos-client/Sources/DictatorApp/main.swift`
- Updated refinement engines to accept injected system prompt text and route selected file content through runtime engine path:
  - `apps/macos-client/Sources/DictatorCore/OllamaRefinementEngine.swift`
  - `apps/macos-client/Sources/DictatorCore/OpenAIRefinementEngine.swift`
  - `apps/macos-client/Sources/DictatorCore/RuntimeConfigRefinementEngine.swift`
  - `apps/macos-client/Sources/DictatorCore/RefinementPromptBuilder.swift` (fallback prompt constant)
- Replaced second overlay placeholder tab with a "System Prompts" view:
  - Added `apps/macos-client/Sources/DictatorApp/LaunchpadSystemPromptsOverlayTab.swift`
  - Updated tab wiring in `apps/macos-client/Sources/DictatorApp/main.swift`
- Added/updated tests for prompt config behavior:
  - `apps/macos-client/Tests/DictatorCoreTests/SystemPromptCatalogTests.swift`
  - `apps/macos-client/Tests/DictatorCoreTests/RuntimeConfigurationManagerTests.swift`
  - `apps/macos-client/Tests/DictatorCoreTests/LLMRuntimeConfigurationTests.swift`
- Updated top-level readme prompt inventory:
  - `README.md`

## Constraints followed
- No spec edits during implementation.
- No contract changes to `/contracts/dictation_v1.yaml`.
