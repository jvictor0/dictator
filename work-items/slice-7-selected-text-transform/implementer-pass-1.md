# Implementer pass 1

## Changes made
- Roadmap:
  - Added Slice 7 in `docs/product/ROADMAP.md`.
- Prompt/runtime behavior:
  - Removed Sheaf/direct-action/wake-name rules.
  - Added two-mode guidance (default refinement + selected-text transform) in:
    - `services/orchestrator/app/services/llm/openai_refiner.py`
    - `prompts/refine_transcript.md`
  - Added selected-text mode logging and selected-text-aware input composition in refiner.
- macOS client:
  - Added selected text capture utility and normalization in `ClipboardInserter`.
  - Captured selected text at recording start in `main.swift` and attached as `optional_context.selected_text`.
- Tests:
  - Added/updated orchestrator tests for new prompt and selected-text input composition.
  - Added Swift tests for selected-text normalization and truncation.
- Documentation:
  - Updated `apps/macos-client/README.md` to describe selected-text mode.

## Constraints followed
- No schema changes to contracts.
- Existing no-selection flow preserved.
