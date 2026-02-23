import XCTest
@testable import DictatorCore

final class LLMRuntimeConfigurationTests: XCTestCase {
    func testFromEnvironmentUsesDefaults() {
        let config = LLMRuntimeConfiguration.fromEnvironment([:])
        XCTAssertEqual(config.provider, .ollama)
        XCTAssertEqual(config.ollamaHost, "http://127.0.0.1:11434")
        XCTAssertEqual(config.ollamaModel, "qwen2.5:7b-instruct")
        XCTAssertEqual(config.fallback, .openai)
        XCTAssertEqual(config.openAIModel, "gpt-4.1-mini")
    }

    func testFromEnvironmentNormalizesAndTrims() {
        let config = LLMRuntimeConfiguration.fromEnvironment([
            "DICTATOR_LLM_PROVIDER": " OPENAI ",
            "DICTATOR_OLLAMA_HOST": " http://localhost:11434/ ",
            "DICTATOR_OLLAMA_MODEL": " qwen2.5-coder:7b ",
            "DICTATOR_LLM_FALLBACK": " NONE ",
            "OPENAI_MODEL": " gpt-4.1 "
        ])

        XCTAssertEqual(config.provider, .openai)
        XCTAssertEqual(config.ollamaHost, "http://localhost:11434")
        XCTAssertEqual(config.ollamaModel, "qwen2.5-coder:7b")
        XCTAssertEqual(config.fallback, .none)
        XCTAssertEqual(config.openAIModel, "gpt-4.1")
    }
}
