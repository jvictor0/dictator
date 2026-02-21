# Roadmap (Execution Slices)

## Goal

Deliver Dictator in small vertical slices that are testable end-to-end.

## Slice 1: Menubar app exists

### Scope

- App launches as a macOS menubar utility.
- Menubar icon/title is visible.
- App can be quit from menubar menu.

### Out of scope

- Hotkeys
- Recording
- Text insertion

### Acceptance criteria

- `swift build` and `swift test` pass.
- Launching the app shows a menubar item.
- Menubar menu includes Quit action.

### Exit artifact

- Demo note in work item proving launch and menubar presence.

## Slice 2: Caps Lock inserts "hello world"

### Scope

- Register Caps Lock as a trigger.
- On trigger, insert `hello world` at the current cursor target.
- Use clipboard paste fallback for insertion path.

### Out of scope

- Recording
- Transcription
- LLM refinement

### Acceptance criteria

- With focus in a text box, pressing Caps Lock inserts `hello world`.
- Works in at least two target apps (for example Notes and TextEdit).
- Failure mode is explicit (permission missing or insertion blocked).

### Risks to manage

- Caps Lock behavior can conflict with system expectations.
- Accessibility and input permissions may be required.

### Exit artifact

- Manual test checklist with at least two app targets.

## Slice 3: Caps Lock toggles recording and inserts "hello world" on stop

### Scope

- First Caps Lock press starts recording.
- Menubar indicator switches to active color while recording.
- Second Caps Lock press stops recording.
- On stop, insert `hello world` (placeholder for future transcript output).

### Out of scope

- Real STT/LLM pipeline integration

### Acceptance criteria

- Press 1 -> recording state `on` and menubar visibly active.
- Press 2 -> recording state `off` and `hello world` inserted.
- State remains consistent across repeated toggles.

### Exit artifact

- Smoke test evidence for toggle state transitions.

## Slice 4: Send audio to Whisper and insert transcript

### Scope

- On stop-recording, send captured audio to STT endpoint/provider.
- Receive transcript text from Whisper path.
- Insert transcript text at cursor (replace `hello world` placeholder behavior).

### Out of scope

- LLM refinement
- Context-aware rewriting

### Acceptance criteria

- After stop-recording, transcript is returned and inserted into active text box.
- If STT fails, user receives clear failure signal and no silent drop.
- End-to-end flow works with configured Whisper path.

### Risks to manage

- Audio format compatibility between app and backend/provider.
- STT latency and timeout handling.

### Exit artifact

- End-to-end manual test evidence with at least one successful transcript insertion.

## Slice 5: Revise transcript with OpenAI API key

### Scope

- Send raw transcript to refinement endpoint/provider using OpenAI API key.
- Insert revised text (not raw transcript) into active text box.
- Preserve fallback behavior if refinement fails (configurable: fail closed or use raw transcript).

### Out of scope

- Long-term context memory
- Personalization beyond basic style preferences

### Acceptance criteria

- Raw transcript is refined via OpenAI-backed step and revised text is inserted.
- API key configuration path is documented and validated at startup/runtime.
- Failure mode is explicit and test-covered (invalid key, rate limit, provider outage).

### Risks to manage

- Prompt/output drift from intended meaning.
- External API reliability and cost controls.

### Exit artifact

- Test evidence showing raw vs revised output and expected insertion result.

## Sequencing and dependencies

- Slice 1 is prerequisite for Slice 2 and Slice 3.
- Slice 2 validates global trigger + insertion path before recording complexity.
- Slice 3 validates record-state UX and toggle control loop.
- Slice 4 depends on Slice 3 recording flow.
- Slice 5 depends on Slice 4 transcript availability.

## Definition of done per slice

- Scope complete
- Acceptance criteria met
- Reviewer approval
- Tester evidence captured in `/work-items/<work-item-id>/`
