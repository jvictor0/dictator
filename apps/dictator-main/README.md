# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Configuration policy

- Environment variables are never used for runtime configuration.
- All non-secret settings are configured via files:
  - `apps/dictator-main/Config/runtime-config.json` (active runtime settings)
  - `apps/dictator-main/Config/runtime-config.safe` (safe restore defaults)
- Secrets are configured via:
  - `apps/dictator-main/Config/secrets.json` (local only, gitignored)
  - `apps/dictator-main/Config/secrets.example.json` (tracked template with empty placeholders)
- On startup, the app reads `secrets.json` once and keeps secrets in memory for the current session.
- Keychain is not used.

## Current behavior

- Menubar status item titled `🫡`
- Pressing Caps Lock toggles recording state
- Recording `on` shows `🔴` indicator in menubar title (`🫡 🔴`)
- Recording `off` runs in-process `DictatorCore` pipeline and inserts returned revised text
- Embedded LAN HTTP server accepts `POST /v1/dictate-audio` (audio/wav + metadata headers) and routes requests through `PipelineOrchestrator.dictate`
- On recording start, app captures frontmost target context and includes it in `optional_context` for dictation
- If text is selected when recording starts, app captures selected text and sends it in `optional_context.selected_text`
- Pressing Backspace during recording cancels/discards the recording
- Empty STT transcript path skips refinement and insertion
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failures (permission missing, STT/refinement failure, insertion failure, missing API key)
- OpenAI key can be managed from menubar menu for the current session (in-memory only)
- Linux daemon mode `dictator-linux` supports CLI-driven record toggle/start/stop/cancel/status over a Unix socket
- Linux insertion path uses Wayland clipboard + synthetic paste (`wl-copy`/`wl-paste` + `wtype`)

## Compatibility

- There are no stable installs for this project.
- Backward compatibility is not a general requirement.

## Runtime config file fields

`runtime-config.json` / `runtime-config.safe` use these keys:

- `version`
- `cloud_model`
- `local_model`
- `use_cloud`
- `fallback_mode`
- `ollama_host`
- `ollama_bin_path`
- `system_prompt`
- `system_prompts_dir`
- `stt_model_path`
- `stt_language`
- `data_dir`
- `interactions_buffer_bytes`
- `dictator_server_enabled`
- `dictator_server_host`
- `dictator_server_port`
- `updated_at`

## Local AI runtime (Ollama + Qwen)

1. Install Ollama (Homebrew or official installer).
2. Start Ollama (`/opt/homebrew/bin/ollama serve`) or launch the Ollama app.
3. Pull the default model:
   - `/opt/homebrew/bin/ollama pull qwen2.5:7b-instruct`
4. Smoke test:
   - `/opt/homebrew/bin/ollama run qwen2.5:7b-instruct "hello"`

Privacy note: when `fallback_mode` is `openai` and a valid OpenAI key is configured, transcripts may be sent to OpenAI if local refinement fails.

## Linux daemon CLI

- Build: `swift build --product dictator-linux`
- Start daemon: `swift run dictator-linux daemon`
- Control commands:
  - `swift run dictator-linux toggle`
  - `swift run dictator-linux start`
  - `swift run dictator-linux stop`
  - `swift run dictator-linux cancel`
  - `swift run dictator-linux status`
  - `swift run dictator-linux health`

Linux runtime dependencies (Arch baseline):
- `pw-record` (PipeWire capture)
- `wl-copy` / `wl-paste` (clipboard)
- `wtype` (paste key simulation)

## Safe restore behavior

- Launchpad button `(-1,0)` triggers `load_safe_runtime_config`.
- This loads `runtime-config.safe` into in-memory runtime config quickly.
- If app is busy (recording/thinking), restore is skipped to avoid mutating live in-flight state.
- Safe restore does not overwrite `runtime-config.json` on disk.

## STT runtime (whisper.cpp)

- Default STT engine is `WhisperCPPBridgeSTTEngine`.
- Runtime is native-only (in-process Whisper bridge).
- Model/language are read from runtime config (`stt_model_path`, `stt_language`).
- If native whisper runtime is not linked or model setup fails, dictation shows explicit `Speech recognition failed: ...`.

## Included wiring points for future slices

- Shared `DictatorCore` abstractions:
  - `STTEngine`
  - `RefinementEngine`
  - `SecretStore`
  - `PipelineOrchestrator`

This scaffold is intentionally thin and not production-complete.
