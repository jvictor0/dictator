# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current slice behavior (Slice 3)

- Menubar status item titled `🫡`
- Pressing Caps Lock toggles recording state
- Recording `on` shows active-color indicator in menubar title
- Recording `off` inserts `hello world` at current cursor target
- Insertion path uses clipboard + synthetic `Cmd+V` and restores prior clipboard contents
- Menubar status line reports explicit failure (for example missing accessibility permission)
- Menubar menu includes `Quit`

## Included wiring points for future slices

- Backend API client models and request/response decoding
- Recording and insertion components kept in scaffold for upcoming slices

This scaffold is intentionally thin and not production-complete.
