import XCTest
@testable import DictatorCore

final class TalonLitePipelineOrchestratorTests: XCTestCase {
    func testValidInputSkipsCorrection() async throws {
        let correction = StubCorrectionEngine(result: .success(""))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air bat cap"),
            correctionEngine: correction
        )

        let result = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(result.outputText, "abc")
        XCTAssertFalse(result.wasLLMCorrected)
        let count = await correction.callCount
        XCTAssertEqual(count, 0)
    }

    func testParseFailureTriggersCorrectionOnce() async throws {
        let correction = StubCorrectionEngine(result: .success("hammer yes no blark"))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "hamer yes no"),
            correctionEngine: correction
        )

        let result = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(result.outputText, "YesNo")
        XCTAssertEqual(result.grammarTranscript, "hammer yes no blark")
        XCTAssertTrue(result.wasLLMCorrected)
        let count = await correction.callCount
        XCTAssertEqual(count, 1)
    }

    func testStripsNonLetterCharactersFromWhisperBeforeParse() async throws {
        let correction = StubCorrectionEngine(result: .success(""))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air, bat. cap!"),
            correctionEngine: correction
        )

        let result = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(result.grammarTranscript, "air bat cap")
        XCTAssertEqual(result.outputText, "abc")
        XCTAssertFalse(result.wasLLMCorrected)
        let count = await correction.callCount
        XCTAssertEqual(count, 0)
    }

    func testCorrectionReceivesSanitizedTranscript() async throws {
        let correction = StubCorrectionEngine(result: .success("hammer yes no blark"))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "hamer, yes? no."),
            correctionEngine: correction
        )

        _ = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        let lastInput = await correction.lastInput
        XCTAssertEqual(lastInput, "hamer yes no")
    }

    func testInvalidCorrectionFailsAtReparse() async {
        let correction = StubCorrectionEngine(result: .success("still invalid"))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "hamer yes no"),
            correctionEngine: correction
        )

        do {
            _ = try await orchestrator.process(
                TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
            )
            XCTFail("Expected failure")
        } catch let error as DictatorError {
            guard case let .talonPipelineFailed(reason) = error else {
                return XCTFail("Unexpected DictatorError: \(error)")
            }
            XCTAssertTrue(reason.contains("reparse"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTopLevelBlarkWithoutOpenBraceFailsRender() async {
        let correction = StubCorrectionEngine(result: .success(""))
        let orchestrator = TalonLitePipelineOrchestrator(
            sttEngine: StubSTTEngine(transcript: "blark"),
            correctionEngine: correction
        )

        do {
            _ = try await orchestrator.process(
                TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
            )
            XCTFail("Expected failure")
        } catch let error as DictatorError {
            guard case let .talonPipelineFailed(reason) = error else {
                return XCTFail("Unexpected DictatorError: \(error)")
            }
            XCTAssertTrue(reason.contains("empty brace stack"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct StubSTTEngine: STTEngine {
    let transcript: String

    func transcribe(_ request: TranscribeRequest) async throws -> TranscribeResponse {
        TranscribeResponse(raw_transcript: transcript, segments: [], confidence: 1.0, duration_ms: 100)
    }
}

private actor StubCorrectionEngine: TalonLiteLLMCorrectionEngine {
    var callCount: Int = 0
    var lastInput: String?
    private let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func correctToGrammar(_ transcript: String) async throws -> String {
        callCount += 1
        lastInput = transcript
        return try result.get()
    }
}
