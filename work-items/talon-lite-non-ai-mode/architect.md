# Architect notes

## Design summary
- Introduce a dedicated Talon-lite parser stack in `DictatorCore`:
  - `TalonLiteParser`
  - `TalonLiteRecoveryEngine` variants (OpenAI/Ollama/runtime-routed)
  - `TalonLiteOrchestrator` for parser-first + one-shot recovery
- Keep mode routing at app layer via Launchpad action and recording-session mode flag.
- Reuse existing insertion path (`ClipboardInserter`) and runtime provider configuration.

## Key decisions
- Unknown-token recovery only applies to parser errors marked recoverable (`unknownToken`).
- Recovery prompt is strict JSON contract with exactly two outcomes:
  - `{"decision":"recovered","transcript":"..."}`
  - `{"decision":"cannot_recover"}`
- No extra retries after failed re-parse.
- Interaction history records Talon-lite events with `mode=talon_lite`.

## Risks
- STT tokenization variance can still produce non-recoverable outputs.
- Provider/network failure during recovery surfaces as explicit Talon recovery failure.
