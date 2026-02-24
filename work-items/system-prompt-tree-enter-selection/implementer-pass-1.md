# Implementer pass 1

## Changes made
- Refactored `LaunchpadSystemPromptsOverlayTab` into tree-based selector model:
  - added expanded-directory state,
  - flattened visible rows with depth,
  - indentation + directory expansion markers in UI rows.
- Added Enter-gated selection behavior:
  - up/down no longer apply runtime config updates,
  - enter applies highlighted file as active prompt path.
- Updated overlay key routing in `main.swift` to treat Enter as overlay navigation input.
- Added tests in `LaunchpadTests`:
  - verify no file selection until Enter,
  - verify right-arrow expansion queries child directory.

## Constraints followed
- No contract changes.
- Existing runtime path-based prompt model preserved.
