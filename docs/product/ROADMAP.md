# Roadmap (Execution Slices)

## Direction Update (Unified Swift Core)

Current implementation direction is a single Swift codebase with shared `DictatorCore` used by:
- macOS caps-lock wrapper app
- iOS host + keyboard wrappers

Legacy backend-oriented slice notes below remain as historical sequencing context.

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

## Slice 6: Active target context for refinement

### Scope

- Capture the active app target when recording starts.
- Include target context in dictation requests (app name; browser site host when available).
- Provide dynamic context sentence for refinement, for example:
  - "You are currently dictating into Codex."
  - "You are currently dictating into Chrome, website google.com."
  - "You are currently dictating into Slack."
- If active target appears to be a coding agent (`Codex` or `Cursor` by string containment), include:
  - "You are talking to a coding agent."
- Use the captured context during transcript refinement to improve intent reconstruction.

### Out of scope

- Persistent per-app memory across sessions
- Deep editor-specific AST or project awareness

### Acceptance criteria

- Dictation request includes optional context derived from active app at recording start.
- Browser targets include site host when available (best effort).
- Coding-agent hint is present when active app matches `Codex` or `Cursor`.
- Refinement prompt/input consumes the context so output can adapt to target environment.
- Unit tests cover context generation and refinement input wiring.

### Risks to manage

- Browser URL detection may fail due to automation permissions or no open tab.
- Frontmost app can change between recording start and stop; system should use the captured start context.

### Exit artifact

- Test evidence showing context payload values and refinement behavior with coding-agent hint.

## Slice 7: Selected-text transform via spoken instruction

### Scope

- Keep existing Caps Lock dictation behavior when no text is selected.
- Add selected-text mode:
  - If text is selected when recording starts, capture the selected text.
  - Continue recording voice as usual.
  - Use transcript as modification request and selected text as source input.
- Refinement prompt supports two modes:
  - transcript cleanup (default),
  - selected-text transform (when selected text is present in context).

### Out of scope

- Multi-turn editing memory
- Non-text binary document transformations

### Acceptance criteria

- With no selected text, behavior is unchanged from current dictation/refinement flow.
- With selected text, backend receives selected text context and transcript request.
- Refiner applies request to selected text using a prompt equivalent to:
  - "Take the following input and modify it based on the following request."
- Output inserts transformed text at cursor/selection target.
- Tests cover selected-text prompt composition and no-regression behavior.

### Risks to manage

- Selected text capture depends on clipboard + synthetic copy sequence.
- Some target apps may block copy/read operations without focused editable selection.

### Exit artifact

- Manual evidence of both paths:
  - no-selection transcript refinement,
  - selection transform with spoken instruction.

## Slice 8: Recording guardrails and cancel controls

### Scope

- Do not start recording unless an editable text input is currently focused.
- While recording, pressing Backspace cancels recording and discards captured audio.
- If STT transcript is empty, skip refinement/OpenAI call and perform no insertion.

### Out of scope

- Complex app-specific focus heuristics beyond accessibility role/editable checks.
- Partial transcript buffering after cancel.

### Acceptance criteria

- Caps Lock start attempt outside text input shows non-recording status and does not capture audio.
- Backspace during recording exits recording state without calling `/v1/dictate` or inserting text.
- Empty STT result returns empty dictate output and bypasses refinement call.
- Tests cover focus-role logic and empty-transcript short-circuit behavior.

### Risks to manage

- Focus detection may vary by host app accessibility metadata.
- Backspace key may still perform host-app deletion in parallel with cancellation.

### Exit artifact

- Manual evidence for all three guardrails with logs showing canceled and skipped paths.

## Sequencing and dependencies

- Slice 1 is prerequisite for Slice 2 and Slice 3.
- Slice 2 validates global trigger + insertion path before recording complexity.
- Slice 3 validates record-state UX and toggle control loop.
- Slice 4 depends on Slice 3 recording flow.
- Slice 5 depends on Slice 4 transcript availability.
- Slice 6 depends on Slice 5 refinement path and uses Slice 3 recording state transitions.
- Slice 7 depends on Slice 5 refinement and reuses Slice 2 clipboard insertion mechanics.
- Slice 8 depends on Slice 3 recording state transitions and Slice 5 refinement flow.

## Definition of done per slice

- Scope complete
- Acceptance criteria met
- Reviewer approval
- Tester evidence captured in `/work-items/<work-item-id>/`
