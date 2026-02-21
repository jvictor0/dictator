import AppKit

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var capsLockTriggerController: CapsLockTriggerController?
    private let recordingController = RecordingController()
    private let audioRecorder = AudioRecorder()
    private let backendManager = BackendServiceManager()
    private var apiClient: APIClient?
    private let sessionID = UUID().uuidString
    private var isHandlingTrigger = false
    private var isBackendStarting = false

    override init() {
        super.init()
    }

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
            Task { @MainActor in
                await self.handleCapsTrigger(menuBarController: menuBarController)
            }
        }

        self.capsLockTriggerController = triggerController
        if triggerController.start() {
            menuBarController.setState("Starting backend...")
            TraceLogger.log("app ready: caps lock trigger armed")
            Task { @MainActor in
                self.isBackendStarting = true
                await self.startManagedBackend(menuBarController: menuBarController)
                self.isBackendStarting = false
            }
        } else {
            menuBarController.setState("Failed: Accessibility permission missing")
            TraceLogger.log("app startup failed: caps lock trigger not armed")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        backendManager.stop()
    }

    @MainActor
    private func handleCapsTrigger(menuBarController: MenuBarController?) async {
        if isHandlingTrigger {
            TraceLogger.log("caps-trigger ignored: previous trigger still in progress")
            menuBarController?.setState("Busy: finishing previous action")
            return
        }

        isHandlingTrigger = true
        defer { isHandlingTrigger = false }

        TraceLogger.log("caps-trigger callback started")

        if !recordingController.isRecording && apiClient == nil {
            if isBackendStarting {
                menuBarController?.setState("Backend starting...")
                TraceLogger.log("caps-trigger rejected: backend still starting")
            } else {
                menuBarController?.setState("Failed: Backend unavailable")
                TraceLogger.log("caps-trigger rejected: backend unavailable")
            }
            return
        }

        if recordingController.isRecording {
            await stopRecordingAndDictate(menuBarController: menuBarController)
        } else {
            await startRecording(menuBarController: menuBarController)
        }
    }

    @MainActor
    private func startRecording(menuBarController: MenuBarController?) async {
        menuBarController?.setState("Starting recording...")
        switch await audioRecorder.start() {
        case .success:
            _ = recordingController.toggle()
            menuBarController?.setIndicatorState(.recording)
            menuBarController?.setState("Recording")
            TraceLogger.log("recording started")
        case let .failure(error):
            menuBarController?.setIndicatorState(.idle)
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording start failed: \(error)")
        }
    }

    @MainActor
    private func stopRecordingAndDictate(menuBarController: MenuBarController?) async {
        _ = recordingController.toggle()
        menuBarController?.setIndicatorState(.idle)
        menuBarController?.setState("Stopping recording...")

        let stopResult = audioRecorder.stop()
        switch stopResult {
        case let .failure(error):
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording stop failed: \(error)")
            return
        case let .success(capturedAudio):
            TraceLogger.log("recording stopped (bytes=\(capturedAudio.data.count), sampleRate=\(capturedAudio.sampleRate))")
            menuBarController?.setIndicatorState(.refining)
            menuBarController?.setState("Transcribing + refining...")

            do {
                let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
                guard let apiClient else {
                    menuBarController?.setState("Failed: Backend unavailable")
                    TraceLogger.log("dictate skipped: api client unavailable")
                    return
                }
                let dictatedCall = try await apiClient.dictate(
                    DictateRequest(
                        audio_b64: capturedAudio.data.base64EncodedString(),
                        sample_rate: capturedAudio.sampleRate,
                        locale: locale,
                        session_id: sessionID
                    )
                )
                let dictated = dictatedCall.response
                TraceLogger.log(
                    "dictate success (rawChars=\(dictated.raw_transcript.count), revisedChars=\(dictated.revised_text.count), transcribeMs=\(dictatedCall.transcribeMs.map(String.init) ?? "n/a"), refineMs=\(dictatedCall.refineMs.map(String.init) ?? "n/a"), summary=\(dictated.edit_summary))"
                )
                TraceLogger.log("dictate raw transcript: \(Self.logSafeText(dictated.raw_transcript))")
                TraceLogger.log("dictate revised text: \(Self.logSafeText(dictated.revised_text))")
                let insertResult = ClipboardInserter.insert(dictated.revised_text)
                switch insertResult {
                case .success:
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("Inserted revised text")
                case let .failure(error):
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("Failed: \(Self.failureMessage(for: error))")
                    TraceLogger.log("revised text insert failed: \(error)")
                }
            } catch {
                menuBarController?.setIndicatorState(.idle)
                menuBarController?.setState("Failed: \(Self.dictationFailureMessage(for: error))")
                TraceLogger.log("dictate failed: \(error)")
            }
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

    private static func recordingFailureMessage(for error: AudioRecorder.RecorderError) -> String {
        switch error {
        case .microphonePermissionMissing:
            return "Microphone permission missing"
        case .recorderSetupFailed:
            return "Recorder setup failed"
        case .startFailed:
            return "Could not start recording"
        case .notRecording:
            return "No active recording"
        case .readFailed:
            return "Could not read captured audio"
        }
    }

    private static func dictationFailureMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            switch apiError {
            case let .badStatus(statusCode):
                return "Dictation request failed (\(statusCode))"
            case .emptyTranscript:
                return "STT returned empty transcript"
            }
        }
        return "Dictation request failed"
    }

    @MainActor
    private func startManagedBackend(menuBarController: MenuBarController) async {
        let result = await backendManager.start()
        switch result {
        case let .success(baseURL):
            apiClient = APIClient(baseURL: baseURL)
            TraceLogger.log("backend manager connected: \(baseURL.absoluteString)")
            menuBarController.setState("Ready (Caps Lock toggles recording)")
        case let .failure(error):
            apiClient = nil
            TraceLogger.log("backend manager failed: \(error)")
            menuBarController.setState("Failed: \(Self.backendFailureMessage(for: error))")
        }
    }

    private static func backendFailureMessage(for error: BackendServiceManager.BackendError) -> String {
        switch error {
        case .repoRootNotFound:
            return "Backend path not found"
        case .pythonNotFound:
            return "Python 3.9+ not found"
        case let .bootstrapFailed(reason):
            return "Backend setup failed: \(String(reason.prefix(90)))"
        case .launchFailed:
            return "Backend launch failed"
        case .healthTimeout:
            return "Backend health timeout"
        case .exitFailed:
            return "Backend did not exit cleanly"
        }
    }

    private static func logSafeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }
}

let app = NSApplication.shared
let delegate = DictatorAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
