# Architect notes

## Design
- Extend overlay tab protocol with async key handler (`handleOverlayKey`) so tabs can own directional key behavior.
- Introduce `LaunchpadConfigOverlayTab` as first tab with:
  - data refresh via runtime configuration manager list API
  - two-column table UI
  - row selection state
  - option cycling logic that calls set API
- Intercept arrow keys in `dispatchLaunchpadKeystroke` when overlay is visible and delegate to overlay controller first.
- Fallback behavior: if overlay does not handle the key, preserve existing keyboard injection flow.

## Reasoning
- Keeps behavior encapsulated in tab-specific logic instead of global key branching.
- Avoids changing Launchpad layout by reusing existing arrow key actions.
- Preserves backwards compatibility for keystrokes outside overlay interactions.
