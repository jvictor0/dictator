import Foundation
import XCTest
@testable import DictatorCore

final class PipelineTests: XCTestCase {
    func testDictateSuccessRunsSTTThenRefinement() async throws {
        let client = PipelineOrchestrator(
            sttEngine: StubSTTEngine(response: TranscribeResponse(raw_transcript: "hello world", segments: [], confidence: 0.9, duration_ms: 1000)),
            refinementEngine: StubRefinementEngine(response: RefineResponse(revised_text: "Hello world.", edit_summary: "ok", uncertainty_flags: []))
        )

        let output = try await client.dictate(
            DictateRequest(audio_b64: Data("audio".utf8).base64EncodedString(), sample_rate: 16000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(output.response.raw_transcript, "hello world")
        XCTAssertEqual(output.response.revised_text, "Hello world.")
        XCTAssertGreaterThanOrEqual(output.transcribeMs, 0)
        XCTAssertGreaterThanOrEqual(output.refineMs, 0)
    }

    func testDictateSkipsRefinementOnEmptyTranscript() async throws {
        let refine = StubRefinementEngine(response: RefineResponse(revised_text: "unused", edit_summary: "unused", uncertainty_flags: []))
        let client = PipelineOrchestrator(
            sttEngine: StubSTTEngine(response: TranscribeResponse(raw_transcript: "  ", segments: [], confidence: 0.0, duration_ms: 0)),
            refinementEngine: refine
        )

        let output = try await client.dictate(
            DictateRequest(audio_b64: Data().base64EncodedString(), sample_rate: 16000, locale: "en-US", session_id: "s")
        )
        let didRun = await refine.didRun()

        XCTAssertEqual(output.response.revised_text, "")
        XCTAssertEqual(output.response.uncertainty_flags, ["empty_transcript_skipped_refinement"])
        XCTAssertFalse(didRun)
    }

    func testOpenAIInputBuildsSelectedTextMode() {
        let built = OpenAIRefinementEngine.buildInput(
            rawTranscript: "make it friendlier",
            optionalContext: ["selected_text": "hello"]
        )
        XCTAssertTrue(built.contains("Input text:"))
        XCTAssertTrue(built.contains("Request:"))
    }

    func testOpenAIInputBuildsContextMode() {
        let built = OpenAIRefinementEngine.buildInput(
            rawTranscript: "ship it",
            optionalContext: ["dictation_context": "You are dictating in Codex", "active_app": "Codex"]
        )
        XCTAssertTrue(built.contains("Context:"))
        XCTAssertTrue(built.contains("Transcript:"))
    }
}

private struct StubSTTEngine: STTEngine {
    let response: TranscribeResponse

    func transcribe(_ request: TranscribeRequest) async throws -> TranscribeResponse {
        response
    }
}

private actor StubRefinementEngine: RefinementEngine {
    let response: RefineResponse
    private var hasRun = false

    init(response: RefineResponse) {
        self.response = response
    }

    func refine(_ request: RefineRequest) async throws -> RefineResponse {
        hasRun = true
        return response
    }

    func didRun() -> Bool {
        hasRun
    }
}
