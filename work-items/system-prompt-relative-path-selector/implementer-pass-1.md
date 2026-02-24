# Implementer pass 1

## Changes made
- Reworked `SystemPromptCatalog` for relative-path operation:
  - recursive `listPromptFiles()` returns relative paths,
  - `listEntries(in:)` returns immediate child files/directories,
  - traversal-safe normalization and `sanitizeRelativePath`.
- Updated runtime system prompt config setter to validate and persist relative paths:
  - `RuntimeSystemPromptConfiguration` now validates against catalog file list.
- Replaced System Prompts tab with selector + preview UI:
  - left panel: directory/file table widget,
  - right panel: active prompt preview,
  - keyboard behavior: up/down select, right enter directory, left parent directory,
  - file selection updates `System Prompt` runtime config immediately.
- Updated app wiring in `main.swift` to provide list/load/get/set closures for the selector.
- Added sample nested prompt directories and files under `prompts/system-prompts/` for testing.
- Updated docs to clarify `system_prompt` is relative path based.

## Tests added/updated
- `SystemPromptCatalogTests` expanded for:
  - nested load,
  - recursive relative listing,
  - directory listing order,
  - traversal sanitization fallback.
- `RuntimeConfigurationManagerTests` updated for nested relative prompt path options and set behavior.

## Constraints followed
- No contract changes.
- No spec modifications during implementation.
