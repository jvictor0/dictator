# Implementer pass 1

## Changes made
- Added Slice 6 roadmap entry in `docs/product/ROADMAP.md`.
- Added `ActiveTargetContextProvider` in macOS client:
  - frontmost app detection
  - browser host extraction for Chrome/Safari (best effort)
  - coding-agent detection for Codex/Cursor
  - normalized context sentence generation
- Updated `DictatorAppDelegate` to:
  - capture context at recording start
  - include captured context in `DictateRequest.optional_context`
- Updated refiner prompt behavior to consume optional context:
  - added context usage guidance in instructions
  - prepended context block in request input when available
- Added tests:
  - Swift smoke tests for host parsing, coding-agent detection, and context sentence formatting
  - Python tests for context instruction and composed request input
- Updated `apps/macos-client/README.md` to reflect Slice 6 behavior.

## Constraints followed
- No contract schema changes.
- Implementer did not modify `SPEC.md` during implementation.
