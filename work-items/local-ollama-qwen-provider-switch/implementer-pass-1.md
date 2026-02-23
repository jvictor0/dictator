# Implementer pass 1

## Summary
Implemented provider-routed refinement for macOS with default local Ollama (`qwen2.5:7b-instruct`) and optional OpenAI fallback.

## Changes
- Added `LLMRuntimeConfiguration` for env-driven provider/model/fallback selection.
- Added `RefinementPromptBuilder` and refactored `OpenAIRefinementEngine` to reuse it.
- Added `OllamaRefinementEngine` with `/api/generate` integration and deterministic error mapping.
- Added `ProviderRoutingRefinementEngine` for primary provider + optional fallback retry.
- Updated app startup wiring in `main.swift` to use provider router and provider-aware readiness messaging.
- Relabeled menu/openai key UX as fallback-oriented.
- Updated `.env.example`, root README, and macOS README for local-default setup.
- Added tests:
  - `LLMRuntimeConfigurationTests`
  - `OllamaRefinementEngineTests`
  - `RefinementProviderRoutingTests`
  - Extended `DotEnvLoaderTests`
  - Extended `PipelineTests` with empty-transcript router regression check.

## Validation
- Run `swift test` in `apps/macos-client`.
- Result: passed (`50` tests, `0` failures).
