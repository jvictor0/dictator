# Architect notes

## Design decisions
- Use an abstract-like base class (`RuntimeConfiguration`) with overridable methods (`getOptions`, `set`) to match Swift virtual method behavior.
- Keep configuration mutation routed through `RuntimeConfigProvider` to preserve single source of in-memory truth.
- Add a dedicated in-memory patch path (`applyInMemoryPatch`) for non-persistent runtime changes.
- Initialize startup defaults from `runtime-config.safe` and expose them via provider.
- Introduce `RuntimeConfigurationManager` to own the list of config objects and provide list/set/reset orchestration.

## Concrete configuration types
- `RuntimeModelConfiguration`
  - `getOptions`: calls Ollama `GET /api/tags`
  - `set`: validates/resolves model then updates provider in memory
- `RuntimeBooleanConfiguration` (`use_cloud`)
  - `getOptions`: `[false, true]`
  - `set`: updates provider in memory

## App integration
- Build the manager at startup with:
  - defaults from safe config
  - current runtime values
- Replace safe-reset action logic with `manager.resetToDefaults()`.

## Tradeoffs
- Voice config interaction now updates runtime config in memory (not on-disk) to satisfy immediate behavior change and avoid file dependency for reset flows.
- Existing file-based patch API remains for callers that still need persistence.
