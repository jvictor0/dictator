# SPEC: local-ollama-qwen-provider-switch

## Scope
Enable local LLM refinement on macOS using Ollama + Qwen as default, while preserving OpenAI as an optional fallback provider.

## In scope
- macOS client only (`apps/macos-client`)
- Provider-based refinement routing (`ollama` primary, `openai` optional fallback)
- New environment configuration for provider/model/host/fallback
- Updated startup status/menu wording for optional OpenAI fallback
- Unit tests for config, Ollama engine behavior, provider routing, and pipeline empty-transcript regression
- Documentation updates (`.env.example`, root README, macOS README)

## Out of scope
- iOS keyboard runtime/provider changes
- Automatic Ollama installation/model download in app runtime
- Contract schema changes (`contracts/dictation_v1.yaml` unchanged)

## Acceptance criteria
1. Default refinement path uses local Ollama model `qwen2.5:7b-instruct`.
2. OpenAI key is optional and used only when provider/fallback requires it.
3. With `DICTATOR_LLM_PROVIDER=ollama` and `DICTATOR_LLM_FALLBACK=openai`, Ollama failure retries through OpenAI when key exists.
4. Without OpenAI key, Ollama failure surfaces deterministic error (no fallback attempt).
5. Existing pipeline behavior remains intact, including empty-transcript skip-refinement behavior.
6. Swift tests pass for updated/new coverage.
