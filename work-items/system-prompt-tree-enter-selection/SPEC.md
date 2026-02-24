# SPEC: Enter-to-select and hierarchical system prompt tree

## Scope
Refine the System Prompts GUI interaction so file selection only commits on Enter, and replace flat directory browsing with a hierarchical tree that keeps parent directories visible and indents subdirectories.

### In scope
- Do not apply `system_prompt` selection when moving highlight with up/down arrows.
- Apply selected file only when Enter is pressed.
- Render a hierarchical tree where opened directories keep ancestor path visible.
- Indent nested entries to represent hierarchy.
- Preserve existing left/right directory navigation semantics.

### Out of scope
- Mouse interaction changes.
- Prompt editing.

## Acceptance criteria
1. Highlight navigation (`up/down`) does not mutate active `system_prompt`.
2. `enter` commits highlighted file to active `system_prompt`.
3. Tree view shows parent directories when deeper directories are opened.
4. Nested entries are visually indented.
5. `right` opens highlighted directory; `left` exits current opened directory.
6. Automated tests cover enter-gated selection and directory expansion behavior.
