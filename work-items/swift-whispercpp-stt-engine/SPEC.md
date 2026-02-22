# SPEC: Activate whisper.cpp STT in DictatorCore

## Goal

Replace the temporary Speech framework STT runtime with whisper.cpp-backed STT in the shared Swift core so macOS dictation uses Whisper for transcription.

## Scope

- Implement a production `WhisperCPPBridgeSTTEngine` in `DictatorCore`.
- Make whisper.cpp engine the default STT engine used by macOS runtime pipeline.
- Preserve existing contract DTO semantics (`TranscribeRequest/Response`).
- Keep refinement flow unchanged (OpenAI key path, fail-closed behavior).
- Add test coverage for whisper engine integration points and failure mapping.

## Out of scope

- iOS keyboard runtime wiring (separate work item).
- Whisper model quality tuning beyond baseline configuration.
- UI redesign.

## Acceptance criteria

1. `swift build` and `swift test` pass in `/Users/joyo/dictator/apps/macos-client`.
2. `DictatorCore` default runtime STT is whisper.cpp (not Speech framework).
3. Dictation no longer depends on `SFSpeechRecognizer` authorization.
4. Whisper errors map to explicit `DictatorError.sttFailed(...)` messages.
5. Existing selected-text/context/refinement behavior remains unchanged.
6. Tests cover at least:
   - successful whisper transcription mapping to contract fields,
   - invalid/unsupported audio payload handling,
   - whisper runtime/model load failure behavior.

## Risks

- Native library/model packaging and runtime loading may vary across dev machines.
- First-run model load may increase latency.

## Dependencies

- Add/confirm whisper.cpp Swift package or vendored wrapper dependency.
- Model path/config strategy documented for local development.
