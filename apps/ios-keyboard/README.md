# iOS Keyboard Wrapper Scaffold

This folder contains the planned iOS wrappers around `DictatorCore`:

- `HostApp/`: onboarding, keyboard enablement guidance, API key management, diagnostics.
- `KeyboardExtension/`: custom keyboard shell that invokes shared core dictation logic.

## Runtime model

- STT: on-device (target architecture is `whisper.cpp` bridge into Swift).
- Refinement: OpenAI API via user-pasted key stored securely and shared with extension.
- Failure policy: refinement failures block insertion and show explicit keyboard error.

## Required entitlements (implementation target)

- Keyboard extension Open Access enabled (`RequestsOpenAccess = YES`) for network refinement.
- Shared key storage via app group/keychain access group.

## Current status

This is a source scaffold documenting target wrappers and interfaces. Xcode project + entitlements wiring is the next step.
