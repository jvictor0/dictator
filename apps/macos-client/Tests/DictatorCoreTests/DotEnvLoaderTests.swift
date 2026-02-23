import XCTest
@testable import DictatorCore

final class DotEnvLoaderTests: XCTestCase {
    func testParseHandlesCommentsWhitespaceAndQuotes() {
        let raw = """
        # comment
        OPENAI_API_KEY=sk-123
        export DICTATOR_WHISPER_MODEL="models/ggml-base.en.bin"
        EMPTY=
        QUOTED='hello world'
        """

        let parsed = DotEnvLoader.parse(raw)
        XCTAssertEqual(parsed["OPENAI_API_KEY"], "sk-123")
        XCTAssertEqual(parsed["DICTATOR_WHISPER_MODEL"], "models/ggml-base.en.bin")
        XCTAssertEqual(parsed["EMPTY"], "")
        XCTAssertEqual(parsed["QUOTED"], "hello world")
    }
}
