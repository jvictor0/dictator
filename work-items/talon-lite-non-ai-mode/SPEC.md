# SPEC: talon-lite-non-ai-mode

## Scope
- Add a new Launchpad action/button for Talon-lite non-AI interaction mode.
- Use Whisper transcription, then parse transcript with Talon-lite tokenizer/parser.
- Support Talon alphabet words, digit words, symbol words (`slash`, `plus`, `minus`, `left paren`, `right paren`) and style commands (`hammer`, `camel`, `snake`, `kebab`).
- Apply one-shot LLM recovery when parse fails due to unknown tokens.
- Re-parse exactly once after recovery; fail with explicit error if still invalid.
- Keep regular dictation/refinement behavior unchanged.

## Non-goals
- Full Talon command set.
- Caps Lock mode changes.
- iOS wrapper changes.
- Contract schema changes in `/Users/joyo/dictator/contracts/dictation_v1.yaml`.

## Acceptance criteria
1. Launchpad layout supports `talon_lite_dictation` action with dictation-style commands.
2. Talon-lite mode runs Whisper + parser-first path without LLM refinement.
3. `air bat cap` resolves to `abc`.
4. `hammer yes no` resolves to `YesNo`.
5. Unknown-token parse failures trigger one LLM recovery attempt only.
6. Recovery output is re-parsed once; if invalid or `cannot_recover`, insertion is skipped and explicit failure status is shown.
7. Regular dictation mode remains unchanged.
8. `swift test` passes in `/Users/joyo/dictator/apps/macos-client`.
