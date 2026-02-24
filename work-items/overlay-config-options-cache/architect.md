# Architect notes

## Design
- Move options loading responsibility from `list()` path to explicit per-config fetch path.
- Add `RuntimeConfigurationManager.getOptions(name:)` API.
- Keep `list()` lightweight (`options=[]`) for table rendering.
- In overlay config tab:
  - add `optionsCache[name]`
  - fetch options on-demand in left/right handler
  - clear cache in `overlayDidClose()`.

## Rationale
- Avoids unnecessary network calls.
- Matches interaction intent exactly.
- Keeps cache lifetime bounded to overlay visibility.
