# SPEC: Versioned system prompt selection and overlay visibility

## Scope
Implement a system prompt abstraction where the active system prompt is selected by file name and can be switched via runtime configuration.

### In scope
- Create a dedicated system prompt directory in `prompts/` and place the current system prompt into its own versioned file.
- Add runtime config support for selected prompt file name (`system_prompt`).
- Add runtime configuration option "System Prompt" whose values are dynamically listed from the system prompt directory.
- Route refinement engines through prompt-file resolution so the selected file name is passed into prompt loading before model invocation.
- Replace the second overlay placeholder tab with a "System Prompts" page that displays the current prompt file and body.

### Out of scope
- Changes to dictation API contract fields.
- Prompt authoring UX beyond the overlay read-only view.

## Acceptance criteria
1. A new directory exists for versioned system prompts, and current prompt text is copied into a file there.
2. Runtime config file model supports `system_prompt` with backward-compatible defaulting.
3. Runtime config manager exposes a "System Prompt" configuration with options equal to files in the system prompt directory.
4. Refinement engines use the selected prompt file content as system/instructions text.
5. The second overlay tab is no longer placeholder content; it renders a "System Prompts" page with active prompt details.
6. Automated tests pass for touched modules, with new coverage for prompt catalog/config behavior.
