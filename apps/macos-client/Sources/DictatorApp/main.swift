import AppKit

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var capsLockTriggerController: CapsLockTriggerController?
    private let recordingController = RecordingController()
    private let audioRecorder = AudioRecorder()
    private let apiClient: APIClient
    private let sessionID = UUID().uuidString
    private var isHandlingTrigger = false

    override init() {
        let baseURL = URL(string: ProcessInfo.processInfo.environment["DICTATOR_API_BASE_URL"] ?? "http://127.0.0.1:8000")!
        self.apiClient = APIClient(baseURL: baseURL)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        TraceLogger.reset()
        TraceLogger.log("app did finish launching")
        TraceLogger.log("trace file: \(TraceLogger.path)")
        TraceLogger.log("api base url: \(apiClient.baseURLDescription)")

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
            menuBarController.setState("Ready (Caps Lock toggles recording)")
            TraceLogger.log("app ready: caps lock trigger armed")
        } else {
            menuBarController.setState("Failed: Accessibility permission missing")
            TraceLogger.log("app startup failed: caps lock trigger not armed")
        }
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

        if recordingController.isRecording {
            await stopRecordingAndTranscribe(menuBarController: menuBarController)
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
            menuBarController?.setRecordingActive(true)
            menuBarController?.setState("Recording")
            TraceLogger.log("recording started")
        case let .failure(error):
            menuBarController?.setRecordingActive(false)
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording start failed: \(error)")
        }
    }

    @MainActor
    private func stopRecordingAndTranscribe(menuBarController: MenuBarController?) async {
        _ = recordingController.toggle()
        menuBarController?.setRecordingActive(false)
        menuBarController?.setState("Stopping recording...")

        let stopResult = audioRecorder.stop()
        switch stopResult {
        case let .failure(error):
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording stop failed: \(error)")
            return
        case let .success(capturedAudio):
            TraceLogger.log("recording stopped (bytes=\(capturedAudio.data.count), sampleRate=\(capturedAudio.sampleRate))")
            menuBarController?.setState("Transcribing...")

            do {
                let locale = Locale.current.identifier
                let transcript = try await apiClient.transcribe(
                    TranscribeRequest(
                        audio_b64: capturedAudio.data.base64EncodedString(),
                        sample_rate: capturedAudio.sampleRate,
                        locale: locale,
                        session_id: sessionID
                    )
                )
                TraceLogger.log("transcribe success (chars=\(transcript.raw_transcript.count))")
                let insertResult = ClipboardInserter.insert(transcript.raw_transcript)
                switch insertResult {
                case .success:
                    menuBarController?.setState("Inserted transcript")
                case let .failure(error):
                    menuBarController?.setState("Failed: \(Self.failureMessage(for: error))")
                    TraceLogger.log("transcript insert failed: \(error)")
                }
            } catch {
                menuBarController?.setState("Failed: \(Self.transcriptionFailureMessage(for: error))")
                TraceLogger.log("transcribe failed: \(error)")
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

    private static func transcriptionFailureMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            switch apiError {
            case let .badStatus(statusCode):
                return "STT request failed (\(statusCode))"
            case .emptyTranscript:
                return "STT returned empty transcript"
            }
        }
        return "STT request failed"
    }
}

let app = NSApplication.shared
let delegate = DictatorAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
