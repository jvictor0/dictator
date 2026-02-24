# Implementer pass 5

## Slice plan and execution

### Slice 1: Persistent interaction storage format + hourly file layout
- Added disk persistence rooted at `Data/interactions`.
- Writes one `.jsonl` file per UTC hour named `YYYY-MM-DDTHHZ.jsonl`.
- On interaction append:
  - creates hourly file if first interaction in that hour,
  - otherwise appends newline-delimited JSON entry.
- Added versioned envelope (`schema_version`, `event_type`, `recorded_at`, `payload`) with payload fields decoded as optional/defaulted values for forward/backward compatibility.

### Slice 2: Startup hydration (latest backward, bounded)
- Added startup hydration logic that scans hourly files newest->oldest and loads until byte budget is reached (newest file always included).
- Hydration is executed in a detached background task (`Task.detached(priority: .utility)`) to avoid startup blocking.
- Loaded interactions are sorted chronologically before seeding in-memory history buffer.

### Slice 3: Concurrency barrier for live interactions during hydration
- Added `InteractionHistoryStore` actor coordinating:
  - startup hydration,
  - append persistence,
  - in-memory buffer updates,
  - UI invalidation callback.
- Live append path now awaits hydration completion before persisting/appending the current interaction.
- `stopRecordingAndDictate` now awaits interaction append on main actor before completion state transition, keeping dictation in thinking state until hydration barrier is cleared and latest interaction is incorporated.

### Slice 4: App wiring + background-safe startup
- App startup now initializes interaction store once with runtime-configured byte budget and data path resolver.
- Data root is resolved via `DICTATOR_DATA_DIR` override or default `Data` under current working directory.
- Runtime "Interactions Buffer" updates now propagate to both in-memory buffer and interaction store.

## Files changed
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/InteractionHistory.swift`
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
- `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/InteractionHistoryTests.swift`

## Validation
- `swift test` passed (99 tests, 0 failures).
