# Architect notes

## Design
- Expand `SystemPromptCatalog` into the authoritative prompt filesystem abstraction:
  - traversal-safe normalization for relative paths,
  - recursive file listing for runtime options,
  - immediate child entry listing for directory navigation UI.
- Preserve runtime config key (`system_prompt`) but reinterpret value as relative path.
- Keep runtime-config-driven selection semantics: GUI selector writes via `RuntimeConfigurationManager` so all downstream behavior is consistent.
- Implement selector behavior inside `LaunchpadSystemPromptsOverlayTab` with a left navigation panel (directory/file list) and right prompt preview panel.

## Tradeoffs
- Selector applies file selection immediately on highlight movement, enabling quick keyboard-only browsing.
- Directory navigation is constrained to prompt root via normalization checks, preventing path escape (`..` beyond root).
- Runtime config options remain available in Config tab (recursive file list), while richer navigation is provided in System Prompts tab.

## Role note
No role skipped.
