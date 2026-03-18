import DictatorCore
import Foundation

public struct CapturedAudioChunk: Sendable {
    public let data: Data
    public let sampleRate: Int

    public init(data: Data, sampleRate: Int) {
        self.data = data
        self.sampleRate = sampleRate
    }
}

public enum DictationLifecycleState: String, Codable, Sendable {
    case idle
    case recording
    case thinking
}

public protocol RecordingBackend: Sendable {
    func startCapture() async throws
    func stopCapture() async throws -> CapturedAudioChunk
    func cancelCapture() async
}

public protocol TextInsertionBackend: Sendable {
    func insertText(_ text: String) throws
}

public protocol TriggerBackend: Sendable {
    func start() async throws
    func stop() async
}

public protocol StatusSink: Sendable {
    func publish(_ message: String)
}

public actor DictationLifecycleController {
    private let coreClient: any DictatorCoreClient
    private let recordingBackend: any RecordingBackend
    private let insertionBackend: any TextInsertionBackend
    private let statusSink: any StatusSink
    private let locale: String
    private let sessionID: String

    private var state: DictationLifecycleState = .idle

    public init(
        coreClient: any DictatorCoreClient,
        recordingBackend: any RecordingBackend,
        insertionBackend: any TextInsertionBackend,
        statusSink: any StatusSink,
        locale: String = "en-US",
        sessionID: String = UUID().uuidString
    ) {
        self.coreClient = coreClient
        self.recordingBackend = recordingBackend
        self.insertionBackend = insertionBackend
        self.statusSink = statusSink
        self.locale = locale
        self.sessionID = sessionID
    }

    public func currentState() -> DictationLifecycleState {
        state
    }

    @discardableResult
    public func startRecording() async -> Bool {
        guard state == .idle else {
            statusSink.publish("Busy: state=\(state.rawValue)")
            return false
        }

        do {
            try await recordingBackend.startCapture()
            state = .recording
            statusSink.publish("Recording")
            return true
        } catch {
            statusSink.publish("Recording start failed: \(error)")
            return false
        }
    }

    @discardableResult
    public func stopRecordingAndProcess(optionalContext: [String: String]? = nil) async -> Bool {
        guard state == .recording else {
            statusSink.publish("Cannot stop: state=\(state.rawValue)")
            return false
        }

        do {
            let captured = try await recordingBackend.stopCapture()
            state = .thinking
            statusSink.publish("Thinking")

            let dictated = try await coreClient.dictate(
                DictateRequest(
                    audio_b64: captured.data.base64EncodedString(),
                    sample_rate: captured.sampleRate,
                    locale: locale,
                    session_id: sessionID,
                    optional_context: optionalContext
                )
            )

            let revised = dictated.response.revised_text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !revised.isEmpty {
                try insertionBackend.insertText(revised)
            }

            state = .idle
            statusSink.publish("Ready")
            return true
        } catch {
            state = .idle
            statusSink.publish("Dictation failed: \(error)")
            return false
        }
    }

    @discardableResult
    public func cancelRecording() async -> Bool {
        guard state == .recording else {
            statusSink.publish("Cannot cancel: state=\(state.rawValue)")
            return false
        }

        await recordingBackend.cancelCapture()
        state = .idle
        statusSink.publish("Cancelled")
        return true
    }

    @discardableResult
    public func toggleRecording(optionalContext: [String: String]? = nil) async -> Bool {
        switch state {
        case .idle:
            return await startRecording()
        case .recording:
            return await stopRecordingAndProcess(optionalContext: optionalContext)
        case .thinking:
            statusSink.publish("Busy: processing")
            return false
        }
    }
}
