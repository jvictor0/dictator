# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current behavior

- Menubar status item titled `🫡`
- Pressing Caps Lock toggles recording state
- Recording `on` shows `🔴` indicator in menubar title (`🫡 🔴`)
- Recording `off` shows `⚪` indicator in menubar title (`🫡 ⚪`)
- Recording `off` runs in-process `DictatorCore` pipeline and inserts returned revised text
- On recording start, app captures frontmost target context and includes it in `optional_context` for `/v1/dictate`
- Target context includes active app, optional browser host (best effort), and coding-agent hint for `Codex`/`Cursor`
- If text is selected when recording starts, app captures selected text and sends it in `optional_context.selected_text`
- When selected text is present, refiner treats voice transcript as an instruction to modify the selected text
- Pressing Backspace during recording cancels/discards the recording
- Empty STT transcript path skips refinement and insertion
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failures (permission missing, STT/refinement failure, insertion failure, missing API key)
- Refinement defaults to local Ollama (`qwen2.5:7b-instruct`) and can optionally fall back to OpenAI
- OpenAI key is managed from menubar menu (`Set OpenAI Key (Fallback)…`, `Clear OpenAI Key (Fallback)`) and stored in macOS Keychain
- App auto-loads `.env` from current directory or parent directories at launch for runtime provider selection and model settings
- Dynamic runtime config is also persisted in `apps/macos-client/Config/runtime-config.json`
- Checked-in safe runtime config lives at `apps/macos-client/Config/runtime-config.safe`
- Precedence for mutable runtime fields: `runtime-config.json` overrides `.env` (`model` and cloud/local provider mode)
- Menubar menu includes `Quit`

## Local AI runtime (Ollama + Qwen)

1. Install Ollama (Homebrew or official installer).
2. Start Ollama (`/opt/homebrew/bin/ollama serve`) or launch the Ollama app.
3. Pull the default model:
   - `/opt/homebrew/bin/ollama pull qwen2.5:7b-instruct`
4. Smoke test:
   - `/opt/homebrew/bin/ollama run qwen2.5:7b-instruct "hello"`

Environment variables for refinement provider:

- `DICTATOR_LLM_PROVIDER`: `ollama` (default) or `openai`
- `DICTATOR_OLLAMA_HOST`: default `http://127.0.0.1:11434`
- `DICTATOR_OLLAMA_MODEL`: default `qwen2.5:7b-instruct`
- `DICTATOR_OLLAMA_BIN`: optional absolute path to Ollama binary for auto-start (example: `/opt/homebrew/bin/ollama`)
- `DICTATOR_LLM_FALLBACK`: `openai` (default) or `none`
- `OPENAI_API_KEY` / `DICTATOR_OPENAI_API_KEY`: optional, used when fallback is `openai`
- `OPENAI_MODEL`: OpenAI model for fallback/default OpenAI provider (default `gpt-4.1-mini`)
- `DICTATOR_RUNTIME_CONFIG_PATH`: optional override for runtime config file path (default resolves to `Config/runtime-config.json` or `apps/macos-client/Config/runtime-config.json`)
- `DICTATOR_RUNTIME_CONFIG_SAFE_PATH`: optional override for safe runtime config file path (default resolves to `Config/runtime-config.safe` or `apps/macos-client/Config/runtime-config.safe`)

Example local-first configuration:

```bash
DICTATOR_LLM_PROVIDER=ollama
DICTATOR_OLLAMA_HOST=http://127.0.0.1:11434
DICTATOR_OLLAMA_MODEL=qwen2.5:7b-instruct
DICTATOR_LLM_FALLBACK=openai
```

Privacy note: when fallback is `openai` and a valid OpenAI key is configured, transcripts may be sent to OpenAI if local refinement fails.

Startup behavior: when `DICTATOR_LLM_PROVIDER=ollama` and `DICTATOR_OLLAMA_HOST` points to loopback (`localhost`/`127.0.0.1`), the app attempts to auto-start `ollama serve` if it is not already reachable.

Safe restore behavior:
- Launchpad button `(-1,0)` triggers `load_safe_runtime_config`.
- This loads `runtime-config.safe` into in-memory runtime config quickly.
- If app is busy (recording/thinking), restore is skipped to avoid mutating live in-flight state.
- Safe restore does not overwrite `runtime-config.json` on disk.

## STT runtime (whisper.cpp)

- Default STT engine is `WhisperCPPBridgeSTTEngine`.
- Runtime is native-only (in-process Whisper bridge).
- Configure model/language via environment:
  - `DICTATOR_WHISPER_MODEL` (default: `models/ggml-base.en.bin`)
  - `DICTATOR_WHISPER_LANGUAGE` (default: `auto`)
- If native whisper runtime is not linked or model setup fails, dictation shows explicit `Speech recognition failed: ...`.

## Included wiring points for future slices

- Shared `DictatorCore` abstractions:
  - `STTEngine`
  - `RefinementEngine`
  - `SecretStore`
  - `PipelineOrchestrator`
- Recording and insertion components kept in scaffold for upcoming slices

This scaffold is intentionally thin and not production-complete.

Note: For this environment, always use `/opt/homebrew/bin/ollama` for Ollama commands.
