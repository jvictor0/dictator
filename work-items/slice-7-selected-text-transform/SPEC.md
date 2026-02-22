# Slice 7 SPEC: Selected-text transform via spoken instruction

## Scope
- Revert refinement prompt to refinement-only behavior (remove Sheaf/direct-action semantics).
- Keep existing Caps Lock dictation behavior when no text is selected.
- Add selected-text transform mode:
  - At recording start, attempt to capture selected text.
  - On stop, send selected text in `optional_context.selected_text` when available.
  - Use transcript as modification request for selected text.
- Preserve existing active-target context capture.

## Out of scope
- New endpoints or contract schema changes.
- Multi-turn editing memory.

## Acceptance criteria
1. System prompt no longer contains Sheaf name/direct-action/wake-name logic.
2. If no selected text exists, behavior matches current transcript refinement flow.
3. If selected text exists, request payload includes `optional_context.selected_text`.
4. Refiner composes selected-text transform input with template:
   - "Take the following input and modify it based on the following request."
5. Output remains single text result inserted through existing insertion path.
6. Tests cover selected-text path and pass across orchestrator + macOS client suites.
