# SPEC: iPhone direct-device deployment scaffolding (host app + keyboard extension)

## Scope

- Keep all iOS deployment work inside this repository.
- Provide an implementation-ready iOS host app + keyboard extension source scaffold.
- Provide entitlements and plist templates for direct on-device deployment (no TestFlight).
- Provide exact Xcode setup/run checklist (target creation, signing, capabilities, install).

## Acceptance criteria

1. Repository contains complete iOS target scaffold files for host app and keyboard extension.
2. Keyboard extension template enables Open Access and declares keyboard extension point.
3. Host + extension entitlements templates include shared App Group and Keychain group placeholders.
4. Key management surface is present in host app source and designed for shared secure storage.
5. Documentation includes step-by-step direct-device run flow in Xcode.
6. Work-item handoff files are complete per `AGENTS.md`.

## Out of scope

- Auto-generating `.xcodeproj` without approved tooling.
- Shipping App Store/TestFlight pipeline.
- Final iOS UI polish.
