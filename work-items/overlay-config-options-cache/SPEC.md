# SPEC: overlay-config-options-cache

## Problem statement
The config overlay currently fetches options too eagerly. We need `getOptions` to be fetched lazily on first left/right interaction and cached while overlay GUI remains open.

## Scope
- Lazy-load options for selected config on first left/right press.
- Cache options per config while overlay is visible/open.
- Clear cache when overlay closes (reload acceptable on next open).

## Acceptance criteria
1. Opening config tab does not require options fetch.
2. First left/right on a config triggers one options fetch.
3. Subsequent left/right on same config uses cached options.
4. Cache clears on overlay close.
5. Tests cover lazy load, reuse, and close-triggered clear behavior.
