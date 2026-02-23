# Implementer Pass 6

## Scope Delivered
Reduced startup keychain prompt churn by avoiding interactive keychain access during launch-state checks.

## Changes
- `apps/macos-client/Sources/DictatorApp/KeychainSecretStore.swift`
  - Added `hasOpenAIKeyWithoutPrompt()` that queries keychain with non-interactive auth context (`LAContext.interactionNotAllowed = true`).
  - Interprets `errSecInteractionNotAllowed` as key-present for startup UX purposes.
- `apps/macos-client/Sources/DictatorApp/main.swift`
  - `hasOpenAIKey()` now uses `secretStore.hasOpenAIKeyWithoutPrompt()`.

## Behavior Impact
- App startup no longer triggers keychain password prompt just to determine "key exists" status.
- Keychain prompt may still appear later when actually reading the key for API use if macOS access control requires interaction.

## Test Evidence
- `swift test` in `apps/macos-client`
- Result: 36 tests passed, 0 failures.
