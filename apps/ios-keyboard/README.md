# iOS Keyboard Wrapper Scaffold

This folder contains direct-device deployment scaffolding for iOS host + keyboard extension.

- `HostApp/`: onboarding, keyboard enablement guidance, diagnostics template.
- `KeyboardExtension/`: keyboard extension shell + placeholder pipeline controller.
- `Shared/`: cross-target constants for app-group identifiers.
- `XCODE_SETUP.md`: exact Xcode checklist for target creation/signing/on-device install.

## Runtime model (target)

- STT: on-device (target architecture is `whisper.cpp` bridge into Swift).
- Refinement: LAN-based pipeline (no API key handling in iOS app/keyboard template).
- Failure policy: refinement failures block insertion and show explicit keyboard error.

## Required entitlements (implementation target)

- Keyboard extension Open Access enabled (`RequestsOpenAccess = YES`) for network refinement.
- Shared app group for extension/host communication.

## Current status

This scaffold is ready for Xcode target wiring in-place within this repo.
No TestFlight setup is required for direct deployment to your personal iPhone.
