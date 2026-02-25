# Implementer pass 1

## Changes made
- Added Talon-lite parser and style formatter:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/TalonLiteParser.swift`
- Added one-shot LLM recovery engines + runtime routing + orchestrator:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/TalonLiteRecoveryEngine.swift`
- Added Dictator error cases for Talon parse/recovery failures:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorCore/Errors.swift`
- Added new Launchpad action type and dispatch wiring:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/LaunchpadDSL.swift`
  - `/Users/joyo/dictator/apps/macos-client/Config/launchpad-layout.json`
- Routed app recording sessions by mode (`standard` vs `talonLite`) and integrated Talon-lite flow:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/main.swift`
- Added interaction history mode for Talon-lite:
  - `/Users/joyo/dictator/apps/macos-client/Sources/DictatorApp/InteractionHistory.swift`
- Added/updated tests:
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/TalonLiteParserTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorCoreTests/TalonLiteRecoveryEngineTests.swift`
  - `/Users/joyo/dictator/apps/macos-client/Tests/DictatorAppTests/LaunchpadTests.swift`

## Test evidence
- Command: `cd /Users/joyo/dictator/apps/macos-client && swift test`
- Result: pass (`113 tests, 0 failures`).

## Known limitations
- Unknown-token recovery is limited to parser `unknownToken` failures by design.
- Talon-lite parser accepts alphabetic literal words as tokens; non-alphabetic unknowns trigger recovery.

## Rollback notes
- Revert the files listed above to remove Talon-lite mode and restore previous Launchpad/action behavior.

## Constraints followed
- `SPEC.md` scope was not changed during implementation.
