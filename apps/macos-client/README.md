# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current slice behavior (Slice 7)

- Menubar status item titled `🫡`
- App-managed backend lifecycle: starts orchestrator automatically on launch and stops managed process on app quit
- Pressing Caps Lock toggles recording state
- Recording `on` shows `🔴` indicator in menubar title (`🫡 🔴`)
- Recording `off` shows `⚪` indicator in menubar title (`🫡 ⚪`)
- Recording `off` sends captured audio to `/v1/dictate` and inserts returned revised text
- On recording start, app captures frontmost target context and includes it in `optional_context` for `/v1/dictate`
- Target context includes active app, optional browser host (best effort), and coding-agent hint for `Codex`/`Cursor`
- If text is selected when recording starts, app captures selected text and sends it in `optional_context.selected_text`
- When selected text is present, backend treats voice transcript as an instruction to modify the selected text
- Recording starts only when an editable text input is focused
- Pressing Backspace during recording cancels/discards the recording
- Empty STT transcript path skips refinement and insertion
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failures (permission missing, STT/refinement failure, insertion failure)
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
