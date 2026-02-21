# Slice 1 SPEC: Menubar app exists

## Problem statement and goals
Ship the first vertical slice of Dictator as a macOS menubar utility that can be launched and exited from the menubar.

## In scope
- App launches as a macOS menubar utility.
- Menubar icon/title is visible.
- Menubar menu includes Quit action and can terminate app.
- `swift build` and `swift test` pass for `apps/macos-client`.

## Out of scope
- Hotkeys
- Recording
- Text insertion

## API/type changes
- No contract/API changes.
- No changes to `/contracts/dictation_v1.yaml`.

## Acceptance criteria
1. `swift build` passes in `/Users/joyo/dictator/apps/macos-client`.
2. `swift test` passes in `/Users/joyo/dictator/apps/macos-client`.
3. Launching app shows a menubar item titled `Dictator`.
4. Menubar menu includes `Quit` action.

## Risks and fallback plan
- Risk: GUI presence cannot be fully asserted in headless/sandboxed environments.
- Fallback: verify launch command succeeds, add unit tests for menu/title structure, and require local manual check in tester evidence.
