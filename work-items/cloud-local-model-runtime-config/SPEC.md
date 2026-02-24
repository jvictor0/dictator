# SPEC: cloud-local-model-runtime-config

## Problem statement
Runtime configuration currently has one model field plus cloud/local mode. We need explicit `Cloud Model` and `Local Model` configurations with defaults sourced from safe runtime config and cloud deployments always using `Cloud Model`.

## Scope
- Add two runtime config fields:
  - `cloud_model`
  - `local_model`
- Keep `use_cloud` as mode selector.
- Ensure provider resolution uses:
  - `cloud_model` when `use_cloud == true`
  - `local_model` when `use_cloud == false`
- Expose both as selectable runtime configurations in overlay config tab.
- Set safe defaults in `runtime-config.safe`.

## In scope
- `DictatorCore` runtime config schema and mapping
- macOS app runtime config manager wiring
- safe/runtime config files in `apps/macos-client/Config`
- tests for runtime mapping and config manager behavior

## Out of scope
- iOS app changes
- contract changes
- unrelated overlay/layout changes

## Acceptance criteria
1. `Cloud Model` and `Local Model` configurations exist and are independently settable.
2. Safe config defaults include `cloud_model` and `local_model`.
3. Cloud mode (`use_cloud=true`) uses `cloud_model` for OpenAI path.
4. Local mode (`use_cloud=false`) uses `local_model` for Ollama path.
5. Existing tests pass; updated tests cover schema/mapping changes.
