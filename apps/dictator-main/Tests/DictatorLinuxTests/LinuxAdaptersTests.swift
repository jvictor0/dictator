import DictatorAppShared
import DictatorCore
import Foundation
@testable import DictatorLinux
import XCTest

final class LinuxAdaptersTests: XCTestCase {
    func testClipboardInserterFailsWhenToolMissing() throws {
        let runner = FakeCommandRunner(available: ["wl-copy", "wl-paste"])
        let inserter = WaylandClipboardInserter(runner: runner)

        XCTAssertThrowsError(try inserter.insertText("hello")) { error in
            guard case LinuxAdapterError.toolMissing(let tool) = error else {
                XCTFail("unexpected error: \(error)")
                return
            }
            XCTAssertEqual(tool, "wtype")
        }
    }

    func testClipboardInserterRestoresClipboard() throws {
        let runner = FakeCommandRunner(
            available: ["wl-copy", "wl-paste", "wtype"],
            cannedOutputs: [
                "wl-paste --no-newline": CommandExecutionResult(status: 0, stdout: Data("before".utf8), stderr: Data())
            ]
        )
        let inserter = WaylandClipboardInserter(runner: runner)

        try inserter.insertText("after")

        XCTAssertTrue(runner.invocations.contains("wtype -M ctrl v -m ctrl"))
        XCTAssertEqual(runner.stdinPayloads["wl-copy "]?.first, Data("after".utf8))
        XCTAssertEqual(runner.stdinPayloads["wl-copy "]?.last, Data("before".utf8))
    }

    func testLifecycleTransitionsThroughThinking() async {
        let recorder = FakeRecorder()
        let insertion = FakeInsertion()
        let core = FakeCoreClient()
        let status = CapturingStatusSink()
        let lifecycle = DictationLifecycleController(
            coreClient: core,
            recordingBackend: recorder,
            insertionBackend: insertion,
            statusSink: status
        )

        let didStart = await lifecycle.startRecording()
        XCTAssertTrue(didStart)

        let stopTask = Task { await lifecycle.stopRecordingAndProcess() }
        try? await Task.sleep(nanoseconds: 20_000_000)
        let mid = await lifecycle.currentState()
        _ = await stopTask.value

        XCTAssertEqual(mid, .thinking)
        let end = await lifecycle.currentState()
        XCTAssertEqual(end, .idle)
        XCTAssertEqual(insertion.lastText, "hello world")
    }
}

private final class FakeCommandRunner: CommandRunning, @unchecked Sendable {
    private let availableSet: Set<String>
    private let cannedOutputs: [String: CommandExecutionResult]
    private(set) var invocations: [String] = []
    private(set) var stdinPayloads: [String: [Data]] = [:]

    init(available: Set<String>, cannedOutputs: [String: CommandExecutionResult] = [:]) {
        availableSet = available
        self.cannedOutputs = cannedOutputs
    }

    func run(_ executable: String, arguments: [String], stdin: Data?) throws -> CommandExecutionResult {
        let key = ([executable] + arguments).joined(separator: " ")
        invocations.append(key)
        stdinPayloads["\(executable) \(arguments.joined(separator: " "))", default: []].append(stdin ?? Data())
        return cannedOutputs[key] ?? CommandExecutionResult(status: 0, stdout: Data(), stderr: Data())
    }

    func isAvailable(_ executable: String) -> Bool {
        availableSet.contains(executable)
    }
}

private final class FakeRecorder: RecordingBackend, @unchecked Sendable {
    func startCapture() async throws {}

    func stopCapture() async throws -> CapturedAudioChunk {
        CapturedAudioChunk(data: Data("audio".utf8), sampleRate: 16_000)
    }

    func cancelCapture() async {}
}

private final class FakeInsertion: TextInsertionBackend, @unchecked Sendable {
    var lastText: String?

    func insertText(_ text: String) throws {
        lastText = text
    }
}

private final class CapturingStatusSink: StatusSink, @unchecked Sendable {
    private(set) var messages: [String] = []

    func publish(_ message: String) {
        messages.append(message)
    }
}

private final class FakeCoreClient: DictatorCoreClient, @unchecked Sendable {
    func transcribe(_ request: DictatorCore.TranscribeRequest) async throws -> DictatorCore.TranscribeResponse {
        _ = request
        return TranscribeResponse(raw_transcript: "raw", segments: [], confidence: 1, duration_ms: 10)
    }

    func refine(_ request: DictatorCore.RefineRequest) async throws -> DictatorCore.RefineResponse {
        _ = request
        return RefineResponse(revised_text: "hello world", edit_summary: "", uncertainty_flags: [])
    }

    func dictate(_ request: DictatorCore.DictateRequest) async throws -> DictatorCore.DictateCallResult {
        _ = request
        try await Task.sleep(nanoseconds: 50_000_000)
        return DictateCallResult(
            response: DictateResponse(raw_transcript: "raw", revised_text: "hello world", edit_summary: "", uncertainty_flags: []),
            transcribeMs: 10,
            refineMs: 20
        )
    }

    func interactForRuntimeConfig(_ request: DictatorCore.VoiceConfigInteractionRequest) async throws -> DictatorCore.VoiceConfigInteractionResult {
        _ = request
        throw DictatorError.configInteractionUnavailable
    }
}
