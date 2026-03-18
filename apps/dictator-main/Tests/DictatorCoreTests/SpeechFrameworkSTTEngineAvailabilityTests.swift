import DictatorCore
import XCTest

final class SpeechFrameworkSTTEngineAvailabilityTests: XCTestCase {
    #if !canImport(Speech)
    func testSpeechEngineUnavailableWithoutSpeechFramework() async {
        let engine = SpeechFrameworkSTTEngine()
        let request = TranscribeRequest(audio_b64: Data().base64EncodedString(), sample_rate: 16_000, locale: "en-US", session_id: "test")

        do {
            _ = try await engine.transcribe(request)
            XCTFail("expected unavailable speech engine to fail")
        } catch {
            XCTAssertTrue(String(describing: error).contains("Speech framework is unavailable"))
        }
    }
    #endif
}
