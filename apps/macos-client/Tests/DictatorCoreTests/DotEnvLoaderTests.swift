import XCTest
@testable import DictatorCore

final class DotEnvLoaderTests: XCTestCase {
    func testParseHandlesCommentsWhitespaceAndQuotes() {
        let raw = """
        # comment
        OPENAI_API_KEY=sk-123
        DICTATOR_LLM_PROVIDER=ollama
        DICTATOR_OLLAMA_HOST=http://127.0.0.1:11434/
        DICTATOR_OLLAMA_MODEL=qwen2.5:7b-instruct
        DICTATOR_LLM_FALLBACK=openai
        export DICTATOR_WHISPER_MODEL="models/ggml-base.en.bin"
        EMPTY=
        QUOTED='hello world'
        """

        let parsed = DotEnvLoader.parse(raw)
        XCTAssertEqual(parsed["OPENAI_API_KEY"], "sk-123")
        XCTAssertEqual(parsed["DICTATOR_LLM_PROVIDER"], "ollama")
        XCTAssertEqual(parsed["DICTATOR_OLLAMA_HOST"], "http://127.0.0.1:11434/")
        XCTAssertEqual(parsed["DICTATOR_OLLAMA_MODEL"], "qwen2.5:7b-instruct")
        XCTAssertEqual(parsed["DICTATOR_LLM_FALLBACK"], "openai")
        XCTAssertEqual(parsed["DICTATOR_WHISPER_MODEL"], "models/ggml-base.en.bin")
        XCTAssertEqual(parsed["EMPTY"], "")
        XCTAssertEqual(parsed["QUOTED"], "hello world")
    }
}
