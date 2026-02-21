# PRD: Dictator (Bootstrap)

## Goal

Enable fast dictation from a macOS menubar app into any text box.

## v1 user flow

1. User presses record hotkey/button.
2. App captures audio until stop.
3. Audio is transcribed via local Whisper path.
4. Transcript is refined by cloud LLM.
5. Revised text is inserted via clipboard paste fallback.

## Non-goals (bootstrap)

- Full production permissions UX
- Rich context memory system
- Advanced accessibility insertion modes

## Success criteria

- End-to-end scaffold compiles/tests with clear extension points.
- Contract is explicit and validated.
- Multi-agent workflow is documented and actionable.

## Delivery plan

- Execution slices are defined in `/Users/joyo/dictator/docs/product/ROADMAP.md`.
