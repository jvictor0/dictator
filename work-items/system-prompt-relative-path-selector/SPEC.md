# SPEC: Relative-path system prompts with directory navigation selector

## Scope
Upgrade system prompt selection from file-name-only to relative path under `prompts/system-prompts/`, and add an interactive selector on the System Prompts tab that supports directory navigation via arrow keys.

### In scope
- `system_prompt` runtime config value is a relative path from system prompt root.
- Prompt catalog supports recursive file discovery and per-directory listing.
- Prompt selector widget on System Prompts tab:
  - `up/down`: change highlighted entry
  - `right`: enter highlighted directory
  - `left`: go to parent directory
- Highlighted file selection updates active runtime `system_prompt` and prompt preview.
- Seed repository with sample nested prompt directories/files for navigation testing.

### Out of scope
- Editing prompt files in GUI.
- Changes to dictation contract schema.

## Acceptance criteria
1. Runtime and refinement pipeline resolve prompts by relative path from system prompt directory.
2. Runtime system prompt configuration options include recursively discovered prompt file paths.
3. System Prompts tab contains a file/directory selector widget and a prompt preview.
4. Arrow key semantics are implemented exactly as specified for navigation.
5. At least two nested directories exist under `prompts/system-prompts/` with sample prompt files.
6. Automated tests pass with added coverage for relative-path and directory listing behavior.
