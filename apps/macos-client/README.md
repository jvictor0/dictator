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
- OpenAI key is managed from menubar menu (`Set OpenAI Key…`, `Clear OpenAI Key`) and stored in macOS Keychain
- Menubar menu includes `Quit`

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
