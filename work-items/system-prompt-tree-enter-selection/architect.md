# Architect notes

## Design
- Keep runtime config integration unchanged and introduce interaction-layer gating: only Enter triggers write-back via `setSelectedPromptPath`.
- Move selector model from flat current-directory list to a tree projection with:
  - `expandedDirectories` state,
  - cached directory entries,
  - flattened visible rows containing depth metadata for indentation.
- Preserve keyboard behavior surface:
  - up/down: move highlighted row,
  - right: expand/open directory,
  - left: collapse current directory and move to parent,
  - enter: commit highlighted file.

## Tradeoffs
- Highlighted file preview still updates without committing selection to aid keyboard exploration.
- Tree is rebuilt from cached directory entries per navigation event for deterministic ordering.

## Role note
No role skipped.
