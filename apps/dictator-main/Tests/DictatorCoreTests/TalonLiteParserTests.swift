import XCTest
@testable import DictatorCore

final class TalonLiteParserTests: XCTestCase {
    func testAlphabetWordsParseToCharacters() throws {
        let parsed = try TalonLiteParser.parse("air bat cap")
        XCTAssertEqual(parsed.outputText, "abc")
        XCTAssertEqual(parsed.style, .plain)
    }

    func testHammerStyleParsesWithCapitalization() throws {
        let parsed = try TalonLiteParser.parse("hammer yes no")
        XCTAssertEqual(parsed.outputText, "YesNo")
        XCTAssertEqual(parsed.style, .hammer)
    }

    func testHammerStyleParsesWithSentencePunctuation() throws {
        let parsed = try TalonLiteParser.parse("Hammer yes no.")
        XCTAssertEqual(parsed.outputText, "YesNo")
        XCTAssertEqual(parsed.style, .hammer)
    }

    func testSnakeStyleParsesWithUnderscores() throws {
        let parsed = try TalonLiteParser.parse("snake yes no")
        XCTAssertEqual(parsed.outputText, "yes_no")
        XCTAssertEqual(parsed.style, .snake)
    }

    func testUnknownTokenThrowsRecoverableError() {
        XCTAssertThrowsError(try TalonLiteParser.parse("air @@@ cap")) { error in
            guard case let TalonLiteParseError.unknownToken(token) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(token, "@@@")
        }
    }
}

final class TalonLiteOrchestratorTests: XCTestCase {
    func testUnknownTokenTriggersRecoveryOnce() async throws {
        let recovery = StubRecoveryEngine(result: .success(.init(kind: .recovered, transcript: "air bat cap")))
        let orchestrator = TalonLiteOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air @@@ cap"),
            recoveryEngine: recovery
        )

        let result = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(result.outputText, "abc")
        XCTAssertEqual(result.recoveredTranscript, "air bat cap")
        let count = await recovery.callCount
        XCTAssertEqual(count, 1)
    }

    func testCannotRecoverFails() async {
        let recovery = StubRecoveryEngine(result: .success(.init(kind: .cannotRecover)))
        let orchestrator = TalonLiteOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air @@@ cap"),
            recoveryEngine: recovery
        )

        do {
            _ = try await orchestrator.process(
                TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
            )
            XCTFail("Expected talon recovery failure")
        } catch let error as DictatorError {
            guard case let .talonRecoveryFailed(reason) = error else {
                return XCTFail("Unexpected DictatorError: \(error)")
            }
            XCTAssertTrue(reason.contains("could not determine"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRecoveryOutputStillInvalidFails() async {
        let recovery = StubRecoveryEngine(result: .success(.init(kind: .recovered, transcript: "air @@@")))
        let orchestrator = TalonLiteOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air @@@ cap"),
            recoveryEngine: recovery
        )

        do {
            _ = try await orchestrator.process(
                TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
            )
            XCTFail("Expected talon recovery failure")
        } catch let error as DictatorError {
            guard case let .talonRecoveryFailed(reason) = error else {
                return XCTFail("Unexpected DictatorError: \(error)")
            }
            XCTAssertTrue(reason.contains("still invalid"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidInputSkipsRecovery() async throws {
        let recovery = StubRecoveryEngine(result: .success(.init(kind: .cannotRecover)))
        let orchestrator = TalonLiteOrchestrator(
            sttEngine: StubSTTEngine(transcript: "air bat cap"),
            recoveryEngine: recovery
        )

        let result = try await orchestrator.process(
            TranscribeRequest(audio_b64: "", sample_rate: 16_000, locale: "en-US", session_id: "s")
        )

        XCTAssertEqual(result.outputText, "abc")
        XCTAssertNil(result.recoveredTranscript)
        let count = await recovery.callCount
        XCTAssertEqual(count, 0)
    }
}

private struct StubSTTEngine: STTEngine {
    let transcript: String

    func transcribe(_ request: TranscribeRequest) async throws -> TranscribeResponse {
        TranscribeResponse(raw_transcript: transcript, segments: [], confidence: 1.0, duration_ms: 100)
    }
}

private actor StubRecoveryEngine: TalonLiteRecoveryEngine {
    var callCount: Int = 0
    private let result: Result<TalonLiteRecoveryDecision, Error>

    init(result: Result<TalonLiteRecoveryDecision, Error>) {
        self.result = result
    }

    func recoverTranscript(_ transcript: String) async throws -> TalonLiteRecoveryDecision {
        callCount += 1
        return try result.get()
    }
}
