# iOS Keyboard Wrapper Scaffold

This folder contains direct-device deployment scaffolding for iOS host + keyboard extension.

- `HostApp/`: onboarding, keyboard enablement guidance, API key management, diagnostics template.
- `KeyboardExtension/`: keyboard extension shell + placeholder pipeline controller.
- `Shared/`: cross-target constants for app-group/keychain identifiers.
- `XCODE_SETUP.md`: exact Xcode checklist for target creation/signing/on-device install.

## Runtime model (target)

- STT: on-device (target architecture is `whisper.cpp` bridge into Swift).
- Refinement: OpenAI API via user-pasted key stored securely and shared with extension.
- Failure policy: refinement failures block insertion and show explicit keyboard error.

## Required entitlements (implementation target)

- Keyboard extension Open Access enabled (`RequestsOpenAccess = YES`) for network refinement.
- Shared key storage via app group/keychain access group.

## Current status

This scaffold is ready for Xcode target wiring in-place within this repo.
No TestFlight setup is required for direct deployment to your personal iPhone.
