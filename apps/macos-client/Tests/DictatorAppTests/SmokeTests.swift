import XCTest
@testable import DictatorApp

final class SmokeTests: XCTestCase {
    func testRecordingToggleFlipsState() {
        let controller = RecordingController()
        XCTAssertFalse(controller.isRecording)
        XCTAssertTrue(controller.toggle())
        XCTAssertTrue(controller.isRecording)
        XCTAssertFalse(controller.toggle())
    }

    func testDecodeDictateResponseShape() throws {
        let json = """
        {
          "raw_transcript": "hello world",
          "revised_text": "Hello world.",
          "edit_summary": "Punctuation normalized.",
          "uncertainty_flags": []
        }
        """.data(using: .utf8)!

        let decoded = try APIClient.decodeDictateResponse(from: json)
        XCTAssertEqual(decoded.revised_text, "Hello world.")
    }
}
