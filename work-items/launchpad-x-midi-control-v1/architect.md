# Architect Notes

## Key Decisions
1. Reactive LED path: use pull-based renderer so state ownership is centralized and deterministic.
2. Dirty signaling: use `RenderInvalidationBus` to avoid idle spinning while allowing immediate wake on changes.
3. Safety fallback: periodic timeout wake to recover from missed signals.
4. 20 Hz render ceiling: chosen to reduce CPU/MIDI traffic while staying responsive.
5. Single active LaunchPad X: simpler v1 behavior while keeping abstractions extensible.
6. JSON DSL: avoids additional dependencies and enables strict schema checks.

## Mapping and Protocol
- LaunchPad X note mapping follows the standard 10-stride grid note layout.
- LED updates use LaunchPad RGB SysEx batching.

## Page/Cell Model
- `LaunchpadCell` owns pressed state + callbacks.
- `getColor` is purely derived from state: dim idle, full when pressed.
- `LaunchpadPageController` switches active page and serves current `ColorProvider` reads.

## Failure Handling
- MIDI send errors cause disconnect and return to searching mode.
- Missing layout file or invalid config logs explicit startup errors.
- Missing accessibility permission blocks key injection but does not crash app.
