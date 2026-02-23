# Implementer Pass 7

## Scope Delivered
Removed local code-signing workflow additions and enforced API key precedence:
1. Environment variable key is always used first.
2. Keychain is used only when no environment key is present.

## Changes
- Added `apps/macos-client/Sources/DictatorCore/APIKeyResolver.swift`
  - Key order: `DICTATOR_OPENAI_API_KEY`, then `OPENAI_API_KEY`.
  - Fallback callback (keychain) is invoked only if env keys are absent.
- Updated `apps/macos-client/Sources/DictatorCore/OpenAIRefinementEngine.swift`
  - Uses `APIKeyResolver.resolve(...)` instead of direct keychain read.
- Updated `apps/macos-client/Sources/DictatorApp/main.swift`
  - Startup key-availability check now returns true immediately when env key exists, avoiding keychain access.
- Added tests: `apps/macos-client/Tests/DictatorCoreTests/APIKeyResolverTests.swift`
  - Verifies env precedence and fallback behavior.
- Removed code-signing additions:
  - deleted `apps/macos-client/scripts/setup-local-codesign.sh`
  - deleted `apps/macos-client/scripts/run-signed-app.sh`
  - removed signing section from `apps/macos-client/README.md`

## Test Evidence
- `swift test` in `apps/macos-client`
- Result: 39 tests passed, 0 failures.

## Behavior Guarantee
- If either env var is present and non-empty, keychain is not queried for API key resolution.
