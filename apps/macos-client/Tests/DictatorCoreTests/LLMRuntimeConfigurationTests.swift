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

    func testRuntimeOverrideWinsForModelAndProvider() {
        let config = LLMRuntimeConfiguration.fromEnvironment(
            [
                "DICTATOR_LLM_PROVIDER": "ollama",
                "DICTATOR_OLLAMA_MODEL": "qwen2.5:7b-instruct",
                "OPENAI_MODEL": "gpt-4.1-mini"
            ],
            runtimeOverride: RuntimeConfigFile(
                version: 2,
                cloudModel: "gpt-4.1",
                localModel: "qwen2.5:7b-instruct",
                useCloud: true,
                updatedAt: "2026-02-23T00:00:00Z"
            )
        )

        XCTAssertEqual(config.provider, .openai)
        XCTAssertEqual(config.openAIModel, "gpt-4.1")
        XCTAssertEqual(config.ollamaModel, "qwen2.5:7b-instruct")
    }
}
