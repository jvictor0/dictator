# iOS Direct-Device Setup

Active iOS project path:

- `apps/ios-keyboard/DictatorKeyboardHost/DictatorKeyboardHost.xcodeproj`

This guide assumes Xcode + iOS signing is already working on this machine.

## 1) Open and configure the existing project

1. Open `DictatorKeyboardHost.xcodeproj` in Xcode.
2. Confirm targets:
   - `DictatorKeyboardHost` (host app)
   - `DictatorKeyboardExtension` (custom keyboard)

## 2) Configure entitlements

1. Host target entitlements: `HostApp/HostApp.entitlements`
2. Extension target entitlements: `DictatorKeyboardExtension/KeyboardExtension.entitlements`
3. Confirm app group: `group.com.joyo.dictator`

## 3) Signing + capabilities

For both targets:

1. Team: your Apple Developer team.
2. Bundle IDs (example):
   - Host: `com.joyo.dictator.host`
   - Extension: `com.joyo.dictator.keyboard`
3. Capabilities:
   - App Groups: `group.com.joyo.dictator`

## 4) Configure keyboard runtime values

1. Set `ios_client_host_url` in host + extension `Info.plist` values to your Mac LAN URL.
2. Keep extension `RequestsOpenAccess = YES` for LAN networking.

## 5) Install on iPhone directly

1. Connect iPhone and trust development profile.
2. Select iPhone as run destination.
3. Run host app target from Xcode.
4. On iPhone:
   - Settings > General > Keyboard > Keyboards > Add New Keyboard...
   - Choose `DictatorKeyboardExtension`
   - Enable `Allow Full Access`
5. Open host app and verify diagnostics.

## 6) Smoke test

1. Open Notes and switch to your custom keyboard.
2. Tap the large dictation button to start/stop recording.
3. Confirm state colors: white (idle), red (recording), blue (waiting for server).
4. Confirm revised text is inserted on successful response.
3. Confirm failure messages are explicit if network/runtime is unavailable.
