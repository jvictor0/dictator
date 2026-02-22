import Foundation
import XCTest
@testable import DictatorCore

final class WhisperCPPBridgeSTTEngineTests: XCTestCase {
    func testParseWhisperJSONMapsContractFields() throws {
        let json = """
        {
          "text": "hello world",
          "transcription": [
            {
              "text": "hello",
              "offsets": { "from": 0, "to": 5000 },
              "avg_logprob": -0.1
            },
            {
              "text": "world",
              "offsets": { "from": 5000, "to": 10000 },
              "avg_logprob": -0.2
            }
          ]
        }
        """.data(using: .utf8)!

        let parsed = try WhisperCPPBridgeSTTEngine.parseWhisperJSON(json)
        XCTAssertEqual(parsed.raw_transcript, "hello world")
        XCTAssertEqual(parsed.segments.count, 2)
        XCTAssertEqual(parsed.segments[0].start_ms, 0)
        XCTAssertEqual(parsed.segments[0].end_ms, 500)
        XCTAssertEqual(parsed.duration_ms, 1000)
        XCTAssertGreaterThan(parsed.confidence, 0)
    }

    func testTranscribeFailsForInvalidBase64() async {
        let engine = WhisperCPPBridgeSTTEngine(
            configuration: .init(binaryPath: "/bin/true", modelPath: "model.bin"),
            runner: { _, _ in .init(exitCode: 0, stdout: "", stderr: "") }
        )

        do {
            _ = try await engine.transcribe(.init(audio_b64: "not-base64", sample_rate: 16000, locale: "en-US", session_id: "s"))
            XCTFail("expected failure")
        } catch let error as DictatorError {
            guard case .sttFailed = error else {
                XCTFail("unexpected error: \(error)")
                return
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testTranscribeMapsWhisperFailure() async {
        let engine = WhisperCPPBridgeSTTEngine(
            configuration: .init(binaryPath: "/usr/bin/env", modelPath: "missing-model.bin"),
            runner: { _, _ in .init(exitCode: 1, stdout: "", stderr: "model missing") }
        )

        do {
            _ = try await engine.transcribe(.init(audio_b64: Data("x".utf8).base64EncodedString(), sample_rate: 16000, locale: "en-US", session_id: "s"))
            XCTFail("expected failure")
        } catch let error as DictatorError {
            guard case let .sttFailed(message) = error else {
                XCTFail("unexpected error: \(error)")
                return
            }
            XCTAssertTrue(message.contains("whisper.cpp failed"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
