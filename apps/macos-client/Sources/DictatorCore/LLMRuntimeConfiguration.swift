import Foundation

public struct LLMRuntimeConfiguration: Sendable {
    public enum Provider: String, Sendable {
        case ollama
        case openai
    }

    public enum Fallback: String, Sendable {
        case openai
        case none
    }

    public let provider: Provider
    public let ollamaHost: String
    public let ollamaModel: String
    public let fallback: Fallback
    public let openAIModel: String

    public init(
        provider: Provider,
        ollamaHost: String,
        ollamaModel: String,
        fallback: Fallback,
        openAIModel: String
    ) {
        self.provider = provider
        self.ollamaHost = ollamaHost
        self.ollamaModel = ollamaModel
        self.fallback = fallback
        self.openAIModel = openAIModel
    }

    public static func fromEnvironment(
        _ env: [String: String] = ProcessInfo.processInfo.environment
    ) -> LLMRuntimeConfiguration {
        let provider = Provider(rawValue: normalized(env["DICTATOR_LLM_PROVIDER"])) ?? .ollama
        let fallback = Fallback(rawValue: normalized(env["DICTATOR_LLM_FALLBACK"])) ?? .openai
        let ollamaHost = normalizedNonEmpty(env["DICTATOR_OLLAMA_HOST"]) ?? "http://127.0.0.1:11434"
        let ollamaModel = normalizedNonEmpty(env["DICTATOR_OLLAMA_MODEL"]) ?? "qwen2.5:7b-instruct"
        let openAIModel = normalizedNonEmpty(env["OPENAI_MODEL"]) ?? "gpt-4.1-mini"

        return LLMRuntimeConfiguration(
            provider: provider,
            ollamaHost: trimTrailingSlash(ollamaHost),
            ollamaModel: ollamaModel,
            fallback: fallback,
            openAIModel: openAIModel
        )
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func trimTrailingSlash(_ value: String) -> String {
        var result = value
        while result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
