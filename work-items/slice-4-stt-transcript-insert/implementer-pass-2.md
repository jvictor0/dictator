# Implementer Pass 2

## Trigger for pass 2
- Tester-reported legitimate usability blocker: app required manually starting backend service.
- Follow-up root-cause from runtime trace: repeated long startup due failed dependency install retries.

## Change summary by file
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/BackendServiceManager.swift`
  - Added wrapper-managed backend lifecycle.
  - Locates orchestrator folder, ensures `.venv` and dependencies, launches uvicorn, waits for `/health`, and stops managed process on app termination.
  - Added Python version compatibility handling for local environment (3.9+).
  - Recreates incompatible venvs and performs dependency import checks before install.
  - Added cached install-failure marker to avoid repeated long reinstall attempts on each app launch.
  - Added timeout and explicit trace logging for setup/launch failures.
- `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
  - Integrated backend manager into app startup.
  - App now blocks trigger flow until backend is available and surfaces explicit backend-unavailable status.
  - Improved backend setup error text with short reason context.
- `/Users/joyo/dictator/apps/macos-client/README.md`
  - Documented app-managed backend behavior and first-run dependency setup attempt.
- `/Users/joyo/dictator/services/orchestrator/pyproject.toml`
  - Updated orchestrator Python requirement to `>=3.9` to match current local runtime and wrapper bootstrap path.

## Test evidence
- `swift test && swift build` passed in `/Users/joyo/dictator/apps/macos-client`.
- Runtime sanity checks showed backend manager state transitions and explicit failure reasons in trace.

## Known limitations
- First-run dependency installation still depends on host Python/pip/network availability.
- If dependency install fails, manager now caches and fails fast for a cooldown window before retry.

## Rollback notes
- Revert files listed above to return to manual-backend startup model.

## Spec integrity statement
- `SPEC.md` scope and acceptance criteria were not changed during pass 2.
