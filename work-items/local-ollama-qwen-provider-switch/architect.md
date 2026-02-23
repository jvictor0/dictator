# Architect notes

## Design rationale
- Keep `PipelineOrchestrator` unchanged by routing provider choice behind `RefinementEngine`.
- Reuse shared prompt/input composition for provider parity between OpenAI and Ollama.
- Use `.env` + process environment as single runtime control surface.
- Preserve backward compatibility for existing OpenAI environment variables and keychain key management.

## Interface additions
- `DICTATOR_LLM_PROVIDER` (`ollama` | `openai`)
- `DICTATOR_OLLAMA_HOST`
- `DICTATOR_OLLAMA_MODEL`
- `DICTATOR_LLM_FALLBACK` (`openai` | `none`)

## Risks
- Local Ollama availability is external runtime dependency.
- Fallback-to-openai can send transcripts remotely; docs must call this out.
