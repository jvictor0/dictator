# Implementer Pass 8

## Scope Delivered
Standardized runtime configuration on `.env` by adding automatic `.env` loading at app launch.

## Changes
- Added `apps/macos-client/Sources/DictatorCore/DotEnvLoader.swift`
  - Discovers `.env` from current directory or parent directories.
  - Parses basic dotenv syntax (`KEY=value`, optional `export`, quoted values, comments).
  - Loads parsed values into process environment at startup.
- Updated `apps/macos-client/Sources/DictatorApp/main.swift`
  - Calls `DotEnvLoader.loadIntoProcessEnvironment()` at launch before key availability checks.
- Updated docs:
  - `apps/macos-client/README.md` now states `.env` is auto-loaded and key resolution remains env-first then keychain fallback.
- Added tests:
  - `apps/macos-client/Tests/DictatorCoreTests/DotEnvLoaderTests.swift`

## Behavior
- `.env` values are now available to all existing environment-based config reads (API key + Whisper model settings).
- API key convention remains:
  1. `.env` / process env (`DICTATOR_OPENAI_API_KEY`, then `OPENAI_API_KEY`)
  2. Keychain fallback only when env key is absent.

## Test Evidence
- `swift test` in `apps/macos-client`
- Result: 40 tests passed, 0 failures.
