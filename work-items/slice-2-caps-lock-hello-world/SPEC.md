# Slice 2 SPEC: Caps Lock inserts hello world

## Problem statement and goals
Add a global Caps Lock trigger that inserts `hello world` into the active text field, while keeping behavior explicit when permissions or insertion fail.

## In scope
- Register Caps Lock as trigger.
- On trigger, attempt insertion of `hello world` at current cursor target.
- Use clipboard paste fallback path.
- Show explicit failure state in menubar status when permission is missing or insertion is blocked.
- Keep menubar quit behavior.

## Out of scope
- Recording
- Transcription
- LLM refinement

## API/type changes
- No changes to `/Users/joyo/dictator/contracts/dictation_v1.yaml`.

## Acceptance criteria
1. `swift build` passes in `/Users/joyo/dictator/apps/macos-client`.
2. `swift test` passes in `/Users/joyo/dictator/apps/macos-client`.
3. With focus in a text box, pressing Caps Lock inserts `hello world`.
4. Manual checklist demonstrates behavior in at least two apps (for example Notes and TextEdit).
5. Failure mode is explicit when permissions are missing or insertion is blocked.

## Risks and fallback plan
- Risk: Accessibility/Input Monitoring permissions may block global key capture or synthetic paste.
- Risk: Caps Lock can conflict with system expectations.
- Fallback: prompt for accessibility trust, and surface explicit status message in menubar when trigger/insertion fails.
