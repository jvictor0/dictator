# Architect notes

## Design decisions
- Evolve `RuntimeConfigFile` from single-model schema to dual-model schema:
  - `cloud_model`
  - `local_model`
  - keep `use_cloud` selector
- Preserve backward compatibility by decoding legacy `model` payloads into both model fields.
- Keep `model` as computed active-model accessor for compatibility at call sites.
- Update runtime configuration resolver so cloud mode always reads `cloud_model`.
- Extend runtime model configuration abstraction to target `.cloud` or `.local` separately.

## Config defaults
- `runtime-config.safe` is the source of truth for default `cloud_model` and `local_model`.

## Operational behavior
- Cloud deploy mode (`use_cloud=true`) routes to OpenAI with `cloud_model`.
- Local deploy mode (`use_cloud=false`) routes to Ollama with `local_model`.
