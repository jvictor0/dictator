# Architect notes

## Design
- Introduce `SystemPromptCatalog` in `DictatorCore` as the abstraction layer for prompt directory discovery, prompt file listing, sanitization, and content loading.
- Extend runtime config schema with `system_prompt` to keep prompt selection in the same mutable runtime path as model/cloud selection.
- Keep `LLMRuntimeConfiguration` as the routing context carrier by adding `systemPrompt` and allowing env fallback (`DICTATOR_SYSTEM_PROMPT`).
- Resolve selected prompt file content once per refinement request in `RuntimeConfigRefinementEngine`, then inject into provider engines.
- Add `RuntimeSystemPromptConfiguration` to expose dynamic options from `SystemPromptCatalog` in existing Launchpad config controls.
- Replace overlay tab #2 with `LaunchpadSystemPromptsOverlayTab` (read-only prompt viewer) instead of placeholder.

## Tradeoffs
- Prompt file read failures fall back to previous embedded prompt text to preserve dictation availability.
- Options are filesystem-driven, so adding versions is file-based and does not require recompilation.
- The overlay prompt viewer is read-only to keep scope small and avoid adding editor state/validation complexity.

## Role note
No role skipped.
