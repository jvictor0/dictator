# SPEC: LaunchPad X MIDI Control v1 (Reactive Color Pipeline)

## Problem Statement
The app needs practical computer control via LaunchPad X before full keyboard/mouse replacement. v1 focuses on resilient MIDI connectivity, a reusable grid/page abstraction, and DSL-defined pad actions.

## Scope
1. Auto-connect to any MIDI controller whose name contains `LaunchPad X`.
2. If disconnected, rescan every 10 seconds and reconnect automatically.
3. Introduce LaunchPad abstractions:
- 8x8 grid model
- page model
- cell callbacks for press/release
- color provider interface
4. Implement reactive LED rendering:
- no direct color sends from interaction code
- pull `getColor` across 64 pads
- diff against cached frame
- send changed pads only
- wake on dirty signal with timeout fallback
- max 20 Hz updates
5. Introduce JSON DSL for pad config (`apps/macos-client/Config/launchpad-layout.json`).
6. Implement first controls: 4 arrow keys with CGEvent injection.

## Out of Scope
- Pressure sensitivity
- Multi-device simultaneous control
- Complex multi-page layouts beyond basic API support
- Full dictation action behavior from LaunchPad (schema support is present)

## Interface Additions
- `ColorProvider`
- `RenderInvalidationBus`
- `LaunchpadColorRenderWorker`
- `LaunchpadMIDIManager`
- `LaunchpadCell`, `LaunchpadPage`, `LaunchpadPageController`, `Grid8x8`
- JSON DSL structs and loader
- `KeyboardInjector`

## Acceptance Criteria
1. LaunchPad X auto-connects at startup when present.
2. When disconnected, app retries every 10 seconds and reconnects without restart.
3. Color writes are renderer-only; interaction paths mark dirty only.
4. Renderer polls colors on wake, diffs frames, sends only changed LEDs.
5. Renderer has dirty-signal wake + timeout fallback and caps output to 20 Hz.
6. Reconnect triggers full redraw.
7. JSON DSL loads and validates, with explicit failure logging.
8. Four configured pads send Up/Down/Left/Right key events.
9. Idle pad color is dimmed; pressed color is full brightness.
10. Tests cover mapping, DSL decode/validation, invalidation wake, and renderer diff behavior.

## Risks
- CoreMIDI endpoint churn: mitigated via repeated name scan + reconnect.
- Accessibility permissions for key injection: explicit logs + graceful no-op.
- Missed wake signal: timeout fallback wake.

## Compatibility
- No contract changes to `contracts/dictation_v1.yaml`.
- Existing dictation flow remains intact.
