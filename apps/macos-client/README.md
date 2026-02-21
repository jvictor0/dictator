# macOS Client Scaffold

Swift menubar scaffold for Dictator.

## Current slice behavior (Slice 2)

- Menubar status item titled `🫡`
- Pressing Caps Lock triggers insertion of `hello world` at current cursor target
- Insertion path uses clipboard + synthetic `Cmd+V` paste fallback
- Menubar status line reports explicit failure (for example missing accessibility permission)
- Menubar menu includes `Quit`

## Included wiring points for future slices

- Backend API client models and request/response decoding
- Recording and insertion components kept in scaffold for upcoming slices

This scaffold is intentionally thin and not production-complete.
