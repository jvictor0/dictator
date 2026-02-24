# Architect notes

## Design rationale
- Keep dynamic config concerns isolated in `DictatorCore` so app wiring stays thin.
- Treat LLM decision output as data, not authority; app enforces all constraints.
- Use an actor-backed config provider for deterministic read-after-write behavior.
- Preserve existing env-based defaults as bootstrap only; runtime JSON governs mutable settings.

## Proposed modules
- `RuntimeConfig`: codable struct for persisted state.
- `RuntimeConfigStore`: file IO (load, create-default, atomic write, patch apply).
- `RuntimeConfigProvider` (actor): in-memory source of truth with update/reload APIs.
- `VoiceConfigUpdateService`: high-level operation that runs STT -> LLM decision -> validated patch apply.

## Decision contract (LLM response)
- Constrained JSON response:
  - `decision`: `no_change` or `update`
  - `update` object optional for `no_change`
  - `update` may include only:
    - `model` (string)
    - `use_cloud` (bool)
- Reject and log any extra keys.

## Integration points
- `apps/macos-client/Sources/DictatorCore/LLMRuntimeConfiguration.swift`
  - Add constructor/adapter from runtime config provider.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - Build engines using provider-backed configuration accessor.
  - Add trigger path for `handleVoiceConfigInteraction()`.
- Existing refinement routing remains, but runtime selection reads provider state.

## Concurrency and consistency
- All config writes serialized through provider actor.
- Apply update in this sequence:
  1. Validate proposed patch.
  2. Persist via atomic write.
  3. Commit new in-memory state.
- If persistence fails, do not mutate in-memory state.

## Security boundaries
- File mutation path hardcodes one destination path.
- No shell/tool execution from LLM-driven update flow.
- No broad JSON merge; allowlist field patch only.

## Observability
- Add trace logs:
  - decision outcome (`no_change`, `update_applied`, `update_rejected`).
  - changed keys and resulting version/timestamp.
- Avoid logging full raw transcript if privacy-sensitive mode exists.

## Rollout plan
1. Add store/provider with tests.
2. Switch runtime reads to provider-backed config.
3. Add voice-update service behind feature flag (optional).
4. Validate and remove flag once stable.
