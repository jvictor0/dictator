# iOS Keyboard App

Canonical iOS implementation lives in:

- `apps/ios-keyboard/DictatorKeyboardHost/HostApp`: host diagnostics and setup guidance.
- `apps/ios-keyboard/DictatorKeyboardHost/DictatorKeyboardExtension`: custom keyboard with mic capture and LAN dictation call.
- `apps/ios-keyboard/DictatorKeyboardHost/DictatorKeyboardHost.xcodeproj`: active Xcode project.

## Runtime model

- Keyboard records 16 kHz mono PCM audio and uploads it to the Dictator macOS app over LAN.
- Dictation endpoint: `POST /v1/dictate-audio` (`audio/wav` payload + metadata headers).
- Keyboard inserts `revised_text` returned by the server.

## Known Roadblock

- On-device microphone capture from the custom keyboard extension is currently blocked in this architecture by iOS extension/runtime constraints.
- Current status: networking + server integration + insertion flow are implemented; extension mic-capture path is paused for later redesign.
- Candidate fallback paths: host-app-managed recording flow, or relying on system dictation path.

## Configuration

- Host URL is read from `ios_client_host_url` in the host/extension `Info.plist`.
- Keyboard extension requires Full Access (`RequestsOpenAccess = YES`) for network requests.
