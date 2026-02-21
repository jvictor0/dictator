import AppKit

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var capsLockTriggerController: CapsLockTriggerController?
    private let recordingController = RecordingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        TraceLogger.reset()
        TraceLogger.log("app did finish launching")
        TraceLogger.log("trace file: \(TraceLogger.path)")

        let menuBarController = MenuBarController()
        self.menuBarController = menuBarController

        let triggerController = CapsLockTriggerController { [weak menuBarController, weak self] in
            guard let self else {
                return
            }
            TraceLogger.log("caps-trigger callback started")
            let isRecording = self.recordingController.toggle()
            menuBarController?.setRecordingActive(isRecording)
            TraceLogger.log("recording state toggled (isRecording=\(isRecording))")

            if isRecording {
                menuBarController?.setState("Recording")
            } else {
                let result = ClipboardInserter.insert("hello world")
                switch result {
                case .success:
                    menuBarController?.setState("Inserted hello world")
                case let .failure(error):
                    TraceLogger.log("caps-trigger callback insert failed: \(error)")
                    menuBarController?.setState("Failed: \(Self.failureMessage(for: error))")
                }
            }
        }

        self.capsLockTriggerController = triggerController
        if triggerController.start() {
            menuBarController.setState("Ready (Caps Lock toggles recording)")
            TraceLogger.log("app ready: caps lock trigger armed")
        } else {
            menuBarController.setState("Failed: Accessibility permission missing")
            TraceLogger.log("app startup failed: caps lock trigger not armed")
        }
    }

    private static func failureMessage(for error: ClipboardInserter.InsertError) -> String {
        switch error {
        case .accessibilityPermissionMissing:
            return "Accessibility permission missing"
        case .clipboardWriteFailed:
            return "Could not write to clipboard"
        case .keyEventSynthesisFailed:
            return "Could not synthesize Cmd+V"
        }
    }
}

let app = NSApplication.shared
let delegate = DictatorAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
