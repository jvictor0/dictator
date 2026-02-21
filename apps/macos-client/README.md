# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current slice behavior (Slice 4)

- Menubar status item titled `🫡`
- App-managed backend lifecycle: starts orchestrator automatically on launch and stops managed process on app quit
- Pressing Caps Lock toggles recording state
- Recording `on` shows `🔴` indicator in menubar title (`🫡 🔴`)
- Recording `off` shows `⚪` indicator in menubar title (`🫡 ⚪`)
- Recording `off` sends captured audio to `/v1/transcribe` and inserts returned transcript
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failures (permission missing, STT failure, insertion failure)
- Menubar menu includes `Quit`

## Backend notes

- Backend URL is managed internally as `http://127.0.0.1:8780` by default.
- On first run (or missing deps), app attempts to prepare backend `.venv` and install orchestrator dependencies automatically.
- Optional overrides: `DICTATOR_BACKEND_HOST`, `DICTATOR_BACKEND_PORT`.
- App uses backend `POST /exit` for graceful shutdown on app quit and to clear stale backend instances on startup.

## Included wiring points for future slices

- Backend API client models and request/response decoding
- Recording and insertion components kept in scaffold for upcoming slices

This scaffold is intentionally thin and not production-complete.
