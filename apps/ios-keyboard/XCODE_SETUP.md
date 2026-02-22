# iOS Direct-Device Setup (No TestFlight)

This guide assumes you already have Xcode + iOS signing working on this machine.

## 1) Create Xcode project in this folder

1. Open Xcode.
2. `File > New > Project... > iOS App`.
3. Save as:
   - Project location: `apps/ios-keyboard`
   - Project name: `DictatorKeyboardHost`
4. Language: Swift, Interface: SwiftUI.

## 2) Add keyboard extension target

1. In project settings, click `+` under Targets.
2. Add `Custom Keyboard Extension` target.
3. Name it `DictatorKeyboardExtension`.

## 3) Wire source files from this repo

Add these groups/files into the project (drag as folder references disabled):

- `apps/ios-keyboard/HostApp/`
- `apps/ios-keyboard/KeyboardExtension/`
- `apps/ios-keyboard/Shared/`

Ensure target membership:

- Host target: `HostApp/*` + `Shared/*`
- Extension target: `KeyboardExtension/*` + `Shared/*`

## 4) Configure entitlements and Info.plist

1. Host target:
   - Set entitlements file to `HostApp/HostApp.entitlements`
2. Extension target:
   - Set entitlements file to `KeyboardExtension/KeyboardExtension.entitlements`
   - Set Info.plist to `KeyboardExtension/Info.plist`

Update placeholders in both entitlements files:

- `$(AppIdentifierPrefix)com.joyo.dictator.shared`
- `group.com.joyo.dictator`

## 5) Signing + capabilities

For both targets:

1. Team: your Apple Developer team.
2. Bundle IDs (example):
   - Host: `com.joyo.dictator.host`
   - Extension: `com.joyo.dictator.keyboard`
3. Capabilities:
   - App Groups: `group.com.joyo.dictator`
   - Keychain Sharing: `$(AppIdentifierPrefix)com.joyo.dictator.shared`

## 6) Build settings for shared core

If you integrate local package targets later, point both targets to the local package path and add `DictatorCore` dependency.
For initial deployment scaffold, this step can be deferred.

## 7) Install on iPhone directly

1. Connect iPhone and trust development profile.
2. Select iPhone as run destination.
3. Run host app target from Xcode.
4. On iPhone:
   - Settings > General > Keyboard > Keyboards > Add New Keyboard...
   - Choose `DictatorKeyboardExtension`
   - Enable `Allow Full Access`
5. Open host app to paste API key and verify diagnostics.

## 8) Smoke test

1. In host app, set API key.
2. Open Notes and switch to your custom keyboard.
3. Confirm keyboard status updates and text insertion path.
4. Confirm failure messages are explicit if key/network/runtime is unavailable.
