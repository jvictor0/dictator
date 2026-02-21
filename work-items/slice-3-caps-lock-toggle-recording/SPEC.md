# Slice 3 SPEC: Caps Lock toggles recording and inserts hello world on stop

## Problem statement and goals
Advance the hotkey flow from immediate insertion to a recording-like toggle model: first Caps Lock press starts recording, second press stops and inserts `hello world`.

## In scope
- First Caps Lock press toggles recording state to on.
- Menubar indicator switches to active color while recording.
- Second Caps Lock press toggles recording state to off.
- On stop, insert `hello world` at cursor target using existing insertion path.
- Preserve explicit failure messages for permission/insertion issues.
- Maintain stable state across repeated toggles.

## Out of scope
- Real microphone capture
- Real STT/LLM pipeline integration

## API/type changes
- No contract changes in `/Users/joyo/dictator/contracts/dictation_v1.yaml`.

## Acceptance criteria
1. `swift build` passes in `/Users/joyo/dictator/apps/macos-client`.
2. `swift test` passes in `/Users/joyo/dictator/apps/macos-client`.
3. Caps Lock press 1 -> recording state on and menubar visually active color.
4. Caps Lock press 2 -> recording state off and `hello world` inserted.
5. State remains consistent across repeated toggles.

## Risks and fallback plan
- Risk: dual local/global event monitors can double-trigger and destabilize toggle state.
- Risk: permission state can prevent insertion while stopping recording.
- Fallback: deduplicate rapid duplicate events and expose explicit status + trace logs for diagnosis.
