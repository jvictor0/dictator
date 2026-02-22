# Architect Notes

## Design rationale

- Keep source-of-truth in repo while respecting that Xcode target creation is an IDE operation.
- Use template-driven setup: code + plist + entitlements + checklist so setup is deterministic.
- Separate responsibilities:
  - Host app: onboarding, key management, diagnostics.
  - Keyboard extension: keyboard UI shell + dictation pipeline invocation.

## Key decisions

1. Direct-device deployment only (developer-signed run from Xcode).
2. Shared secret storage via App Group + Keychain access group templates.
3. Keyboard extension requests Open Access for network refinement path.

## Tradeoffs

- Manual Xcode target wiring is required, but no extra local tool installation is needed.
- Scaffold-first approach accelerates setup while preserving flexibility for final app branding.
