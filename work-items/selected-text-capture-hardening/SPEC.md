# SPEC: Harden selected-text capture against stale clipboard reuse

## Scope
- Ensure selected-text capture does not reuse pre-existing clipboard content when no fresh copy occurs.
- Improve selected-text detection criteria to require evidence of a fresh pasteboard write before accepting selected text.
- Keep clipboard restore behavior unchanged after capture attempt.
- Add tests covering stale-clipboard rejection and fresh-copy acceptance.

## Out of scope
- Changes to STT/refinement API contract.
- Changes to insertion behavior.

## Acceptance criteria
1. `captureSelectedText` only returns selected text when pasteboard change count advances after synthetic `Cmd+C`.
2. If change count does not advance, selected text resolves to `nil` even when clipboard already contains text.
3. Existing text normalization rules (trim, empty rejection, length cap) still apply.
4. Unit tests cover:
- no change-count advance => nil
- change-count advance + valid text => selected text
- change-count advance + whitespace-only => nil
5. macOS client test suite passes.
