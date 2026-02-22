# Tester Evidence

## Automated tests
- Command: `swift test`
- Working directory: `/Users/joyo/dictator/apps/macos-client`
- Result: pass (26 tests, 0 failures)

## Relevant coverage
- `testExtractSelectedTextIgnoresClipboardWhenChangeCountDidNotAdvance`
- `testExtractSelectedTextAcceptsFreshClipboardCopy`
- `testExtractSelectedTextRejectsWhitespaceWhenChangeCountAdvances`

## Confidence
- High for stale-clipboard prevention in selected-text detection and no regression in existing macOS client suite.
