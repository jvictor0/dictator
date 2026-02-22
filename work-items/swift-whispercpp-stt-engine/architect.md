# Architect Notes

## Design rationale

- Keep STT swapping isolated behind `STTEngine` so wrapper apps remain unchanged.
- Implement whisper.cpp as a concrete `WhisperCPPBridgeSTTEngine` and switch `main.swift` pipeline assembly to that engine.
- Maintain contract stability by mapping whisper segments/confidence/duration into existing `TranscribeResponse` fields.

## Proposed implementation

1. Add whisper.cpp dependency in `apps/macos-client/Package.swift` (or local wrapper module).
2. Introduce a small adapter layer:
   - decode incoming `audio_b64` to temp audio file,
   - run whisper transcription,
   - map output segments and confidence values.
3. Update runtime wiring in `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`:
   - use `WhisperCPPBridgeSTTEngine()` as default.
4. Keep `SpeechFrameworkSTTEngine` as fallback-only implementation for troubleshooting (not default).

## Configuration

- Add explicit model configuration source (env/config constant) with safe default.
- Log selected model path and clear startup failures to trace log.

## Tradeoffs

- Whisper integration adds native dependency complexity but improves transcript consistency and quality.
- Retaining Speech framework as non-default fallback reduces recovery time if whisper packaging fails.
