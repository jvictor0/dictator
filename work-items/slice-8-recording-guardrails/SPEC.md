# Slice 8 SPEC: Recording guardrails and cancel controls

## Scope
- Prevent recording start unless editable text input is focused.
- While recording, Backspace cancels and discards recording.
- If STT transcript is empty, skip refinement/OpenAI and do nothing (no insertion).

## Out of scope
- Full app-specific accessibility heuristics beyond role/editable checks.
- Recovering canceled audio.

## Acceptance criteria
1. Caps Lock start attempt with no focused text input does not start recorder.
2. Backspace press during active recording stops recorder and avoids `/v1/dictate` processing.
3. Empty STT transcript short-circuits before refinement provider call.
4. Empty revised output path performs no insertion in client.
5. Tests cover new decision logic and all suites pass.
