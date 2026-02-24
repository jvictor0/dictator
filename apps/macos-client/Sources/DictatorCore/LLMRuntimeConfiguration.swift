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
    public let systemPrompt: String

    public init(
        provider: Provider,
        ollamaHost: String,
        ollamaModel: String,
        fallback: Fallback,
        openAIModel: String,
        systemPrompt: String = SystemPromptCatalog.defaultPromptFile
    ) {
        self.provider = provider
        self.ollamaHost = ollamaHost
        self.ollamaModel = ollamaModel
        self.fallback = fallback
        self.openAIModel = openAIModel
        self.systemPrompt = systemPrompt
    }

    public static func fromEnvironment(
        _ env: [String: String] = ProcessInfo.processInfo.environment,
        runtimeOverride: RuntimeConfigFile? = nil
    ) -> LLMRuntimeConfiguration {
        let provider = Provider(rawValue: normalized(env["DICTATOR_LLM_PROVIDER"])) ?? .ollama
        let fallback = Fallback(rawValue: normalized(env["DICTATOR_LLM_FALLBACK"])) ?? .openai
        let ollamaHost = normalizedNonEmpty(env["DICTATOR_OLLAMA_HOST"]) ?? "http://127.0.0.1:11434"
        let ollamaModel = normalizedNonEmpty(env["DICTATOR_OLLAMA_MODEL"]) ?? "qwen2.5:7b-instruct"
        let openAIModel = normalizedNonEmpty(env["OPENAI_MODEL"]) ?? "gpt-4.1-mini"
        let systemPrompt = normalizedNonEmpty(env["DICTATOR_SYSTEM_PROMPT"]) ?? SystemPromptCatalog.defaultPromptFile

        var resolved = LLMRuntimeConfiguration(
            provider: provider,
            ollamaHost: trimTrailingSlash(ollamaHost),
            ollamaModel: ollamaModel,
            fallback: fallback,
            openAIModel: openAIModel,
            systemPrompt: systemPrompt
        )

        guard let runtimeOverride else {
            return resolved
        }

        if runtimeOverride.useCloud {
            resolved = LLMRuntimeConfiguration(
                provider: .openai,
                ollamaHost: resolved.ollamaHost,
                ollamaModel: runtimeOverride.localModel,
                fallback: resolved.fallback,
                openAIModel: runtimeOverride.cloudModel,
                systemPrompt: runtimeOverride.systemPrompt
            )
        } else {
            resolved = LLMRuntimeConfiguration(
                provider: .ollama,
                ollamaHost: resolved.ollamaHost,
                ollamaModel: runtimeOverride.localModel,
                fallback: resolved.fallback,
                openAIModel: runtimeOverride.cloudModel,
                systemPrompt: runtimeOverride.systemPrompt
            )
        }

        return resolved
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
