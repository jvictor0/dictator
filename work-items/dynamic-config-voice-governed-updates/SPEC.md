# SPEC: dynamic-config-voice-governed-updates

## Problem statement
Current runtime LLM settings are primarily environment-driven. We need a dynamic, persisted configuration path that can be updated during runtime from voice-triggered LLM interactions, with strict write boundaries.

## Scope
Introduce JSON-backed runtime configuration and a high-level API that allows an LLM to interpret voice input and optionally apply a configuration change immediately.

## In scope
- macOS client (`apps/macos-client`) only.
- New JSON config file as persisted source for dynamic settings.
- Initial dynamic settings:
  - active model identifier.
  - cloud usage flag.
- New high-level API entrypoint to trigger “listen + decide + maybe update config”.
- Strict “config-file-only” mutation policy for this flow.
- Immediate in-memory and on-disk effect for accepted changes.
- Unit/integration tests for parsing, update gating, and immediate effect.
- Documentation updates for runtime behavior and safety constraints.

## Out of scope
- iOS keyboard app changes.
- Changes to `contracts/dictation_v1.yaml` unless new external API contract is explicitly requested in a follow-up.
- Broad tool/function-calling framework; this is intentionally ad hoc logic for one file.
- Multi-file write automation from the LLM.

## Proposed data model
- File path: `apps/macos-client/Config/runtime-config.json`
- Shape:
  - `model`: string
  - `use_cloud`: boolean
  - `updated_at`: ISO-8601 string (managed by app)
  - `version`: integer (start at `1`)

Example:
```json
{
  "version": 1,
  "model": "qwen2.5:7b-instruct",
  "use_cloud": false,
  "updated_at": "2026-02-23T00:00:00Z"
}
```

## High-level API plan
- Add a new orchestrator-level operation (naming draft): `handleVoiceConfigInteraction()`.
- Flow:
  1. Capture/transcribe voice input with existing STT pipeline.
  2. Send transcript + current config snapshot to a constrained LLM prompt.
  3. LLM returns either:
     - `no_change`, or
     - `update` with partial fields (`model` and/or `use_cloud`).
  4. Validate response against strict schema.
  5. If valid update exists, atomically write JSON file and refresh in-memory config cache.
  6. Emit status/log message and return result to caller.

## Safety and boundaries
- LLM output must be treated as untrusted.
- Apply allowlist validation:
  - allowed keys: `model`, `use_cloud`.
  - no extra keys accepted from LLM payload.
- Only one write target is allowed: `runtime-config.json`.
- Use atomic write (`tmp` + rename) to avoid partial corruption.
- Reject invalid JSON, invalid type, unknown keys, or empty updates.
- No subprocess execution or arbitrary file ops in this path.

## Immediate effect requirements
- Introduce a runtime configuration provider with:
  - `current()` to read in-memory state.
  - `reloadFromDisk()` and `apply(_ patch:)`.
- Components that route LLM provider/model must consult provider state (not stale env snapshot) for each request or subscribe to updates.
- After accepted update, next refinement request must observe new settings without app restart.

## Implementation steps
1. Add config types and file store (`DictatorCore`), including load/default/write/atomic update.
2. Add runtime config provider + synchronization strategy (`actor` recommended).
3. Integrate provider into existing engine selection path in `main.swift`/runtime assembly.
4. Add high-level API for voice-triggered config decisions.
5. Add constrained prompt + parser for `no_change | update`.
6. Add validation + file-only mutation guard.
7. Add tests:
   - config default/load/save/atomic write.
   - allowed-key enforcement and rejection paths.
   - immediate effect path (before/after model + cloud flag behavior).
8. Update docs: root/macOS README and work-item evidence files.

## Acceptance criteria
1. App creates/uses `runtime-config.json` and persists `model` + `use_cloud`.
2. Voice config API can return “no change” without side effects.
3. Voice config API can apply valid change and write only `runtime-config.json`.
4. Invalid/unsafe LLM output is rejected with no file mutation.
5. Accepted update takes effect immediately for subsequent runtime decisions.
6. Tests cover success, rejection, and immediate-effect behavior.

## Risks
- Concurrency between active dictation requests and config updates.
- Prompt ambiguity leading to over-eager config edits.
- Drift between env defaults and JSON runtime source.

## Mitigations
- Serialize update path with an actor-backed provider.
- Use explicit intent schema (`no_change` vs `update`) with strict decoding.
- Define precedence order clearly (JSON runtime config overrides env for mutable fields).
