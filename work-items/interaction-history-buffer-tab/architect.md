# Architect notes

## Design
- Keep interaction capture in the macOS app layer (`DictatorApp`) where timing, insertion result, context, and UI integration already converge.
- Add a dedicated `DictationInteraction` model plus `DictationInteractionBuffer` with eviction-by-size semantics.
- Extend runtime config schema with `interactions_buffer_bytes` and expose it as a runtime configuration entry (`Interactions Buffer`).
- Replace placeholder overlay tab with `LaunchpadInteractionsOverlayTab`, backed by a read-only snapshot loader closure from the in-memory buffer.

## Rationale
- This minimizes core API contract churn while still using existing pipeline abstractions.
- Buffer size and behavior become operator-tunable through the same runtime config flow as model/system prompt settings.
- UI tab remains decoupled from capture internals via a simple loader abstraction.
