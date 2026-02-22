# Architect Notes

## Design rationale

- Keep contract schema stable by porting request/response shapes from `contracts/dictation_v1.yaml` directly into shared Swift DTOs.
- Separate I/O and AI via protocols (`AudioInputPort`, `STTEngine`, `RefinementEngine`, `SecretStore`) to enable wrapper reuse across macOS/iOS.
- Remove cross-process HTTP hop to reduce startup complexity and eliminate Python runtime dependency.
- Keep refinement fail-closed by default for key/network/auth failures.

## Key decisions

1. Shared core lives in Swift package target `DictatorCore`.
2. macOS app uses Keychain-backed secret storage.
3. iOS keyboard path is scaffolded with host app + extension boundary documentation.
4. whisper.cpp integration point is represented as `WhisperCPPBridgeSTTEngine` placeholder for follow-up implementation.

## Tradeoffs

- Using `SpeechFrameworkSTTEngine` as current runtime STT keeps app functional now, but does not yet satisfy whisper.cpp production integration.
- iOS wrappers are scaffolds in this pass; full shipping keyboard target remains follow-up.
