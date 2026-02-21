# Implementer Pass 2

## Trigger for pass 2
- Tester-reported legitimate usability blocker: app required manually starting backend process.

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/BackendServiceManager.swift`
  - Added wrapper-managed backend lifecycle.
  - Locates orchestrator folder, ensures `.venv` and dependencies, launches uvicorn, waits for `/health`, and stops managed process on app termination.
  - Added timeout and explicit trace logging for setup/launch failures.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Integrated backend manager into app startup.
  - App now blocks trigger flow until backend is available and surfaces explicit backend-unavailable status.
  - Removed external base-url runtime dependency from primary flow.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Documented app-managed backend behavior and first-run dependency setup attempt.

## Test evidence
- `swift test && swift build` passed in `/Users/joyo/dictator/apps/macos-client`.
- Runtime sanity checks showed backend manager state transitions and explicit failure messages in trace.

## Known limitations
- First-run dependency installation still depends on system Python/pip and network/package availability.
- Backend bootstrap failure is explicit, but cannot be recovered if host environment blocks package install.

## Rollback notes
- Revert files listed above to return to manual-backend startup model.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during pass 2.
