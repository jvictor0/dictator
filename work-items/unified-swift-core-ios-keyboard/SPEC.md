# SPEC: Unified Swift core for macOS caps-lock + iOS keyboard wrappers

## Scope

- Replace Python orchestrator runtime dependency with in-process Swift pipeline.
- Introduce shared `DictatorCore` module with contract DTOs and orchestration interfaces.
- Migrate macOS wrapper to direct `DictatorCoreClient` calls.
- Add secure OpenAI key management abstraction and macOS Keychain implementation.
- Add iOS wrapper scaffold (`apps/ios-keyboard`) documenting host/extension split.

## Acceptance criteria

1. `apps/macos-client` builds/tests with no runtime `services/orchestrator` dependency.
2. Shared `DictatorCore` target exposes:
   - `DictatorCoreClient`
   - `STTEngine`
   - `RefinementEngine`
   - `SecretStore`
   - `PipelineOrchestrator`
3. macOS caps-lock flow still records, dictates, and inserts revised text.
4. Missing/invalid OpenAI key surfaces explicit failure and blocks insertion.
5. Menubar provides key management actions (set/clear).
6. Repository docs updated to unified Swift architecture.

## Non-goals for this pass

- Full iOS Xcode project and entitlements wiring.
- Production whisper.cpp integration (interface/scaffold only).
- Manual iOS keyboard runtime validation.
