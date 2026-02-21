# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current slice behavior (Slice 4)

- Menubar status item titled `🫡`
- Pressing Caps Lock toggles recording state
- Recording `on` shows `🔴` indicator in menubar title (`🫡 🔴`)
- Recording `off` shows `⚪` indicator in menubar title (`🫡 ⚪`)
- Recording `off` sends captured audio to `/v1/transcribe` and inserts returned transcript
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failures (permission missing, STT failure, insertion failure)
- Menubar menu includes `Quit`

## Runtime config

- `DICTATOR_API_BASE_URL` (optional): defaults to `http://127.0.0.1:8000`

## Included wiring points for future slices

- Backend API client models and request/response decoding
- Recording and insertion components kept in scaffold for upcoming slices

This scaffold is intentionally thin and not production-complete.
