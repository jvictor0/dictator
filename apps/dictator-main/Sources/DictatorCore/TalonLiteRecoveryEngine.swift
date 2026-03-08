import Foundation

public protocol TalonLiteLLMCorrectionEngine: Sendable {
    func correctToGrammar(_ transcript: String) async throws -> String
}

public final class RuntimeConfigTalonLiteLLMCorrectionEngine: TalonLiteLLMCorrectionEngine {
    private let runtimeConfigProvider: RuntimeConfigProvider
    private let secretStore: SecretStore
    private let session: URLSession
    private let canUseOpenAI: @Sendable () -> Bool

    public init(
        runtimeConfigProvider: RuntimeConfigProvider,
        secretStore: SecretStore,
        session: URLSession = .shared,
        canUseOpenAI: @escaping @Sendable () -> Bool
    ) {
        self.runtimeConfigProvider = runtimeConfigProvider
        self.secretStore = secretStore
        self.session = session
        self.canUseOpenAI = canUseOpenAI
    }

    public func correctToGrammar(_ transcript: String) async throws -> String {
        let configuration = await runtimeConfigProvider.currentConfiguration()

        let ollamaEngine = OllamaTalonLiteLLMCorrectionEngine(
            host: configuration.ollamaHost,
            model: configuration.ollamaModel,
            session: session
        )
        let openAIEngine = OpenAITalonLiteLLMCorrectionEngine(
            model: configuration.openAIModel,
            secretStore: secretStore,
            session: session
        )

        switch configuration.provider {
        case .openai:
            return try await openAIEngine.correctToGrammar(transcript)
        case .ollama:
            do {
                return try await ollamaEngine.correctToGrammar(transcript)
            } catch {
                guard configuration.fallback == .openai, canUseOpenAI() else {
                    throw error
                }
                return try await openAIEngine.correctToGrammar(transcript)
            }
        }
    }
}

public final class OpenAITalonLiteLLMCorrectionEngine: TalonLiteLLMCorrectionEngine {
    private let model: String
    private let secretStore: SecretStore
    private let session: URLSession

    public init(
        model: String,
        secretStore: SecretStore,
        session: URLSession = .shared
    ) {
        self.model = model
        self.secretStore = secretStore
        self.session = session
    }

    public func correctToGrammar(_ transcript: String) async throws -> String {
        guard let key = try APIKeyResolver.resolve(fallback: { try secretStore.getOpenAIKey() }) else {
            throw DictatorError.missingApiKey
        }

        let payload = ResponsesPayload(
            model: model,
            instructions: Self.instructions,
            input: Self.input(transcript: transcript)
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(urlError.code)
            {
                throw DictatorError.networkUnavailable
            }
            throw DictatorError.talonPipelineFailed("llm_correction: \(String(describing: error))")
        }

        guard let http = response as? HTTPURLResponse else {
            throw DictatorError.talonPipelineFailed("llm_correction: invalid server response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw DictatorError.invalidApiKey
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DictatorError.talonPipelineFailed("llm_correction: \(String(message.prefix(220)))")
        }

        let decoded = try JSONDecoder().decode(ResponsesOutput.self, from: data)
        guard let output = decoded.firstOutputText,
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw DictatorError.talonPipelineFailed("llm_correction: OpenAI response did not include output text")
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let instructions = """
    You are correcting Whisper transcripts into Talon Lite utterances.

    \(TalonLiteGrammarParser.grammarText)

    Rules:
    - Output a single corrected Talon Lite transcript that matches the grammar exactly.
    - Use only tokens and operators allowed by the grammar.
    - Do not include explanations, JSON, markdown, or extra commentary.
    - If unsure, output the closest valid grammar-conforming utterance.
    """

    private static func input(transcript: String) -> String {
        """
        Whisper transcript (possibly incorrect):
        \(transcript)
        """
    }

    private struct ResponsesPayload: Encodable {
        let model: String
        let instructions: String
        let input: String
    }

    private struct ResponsesOutput: Decodable {
        let output_text: String?
        let output: [ResponsesOutputItem]?

        var firstOutputText: String? {
            if let outputText = output_text,
               !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return outputText
            }
            return output?
                .flatMap { $0.content ?? [] }
                .compactMap { $0.text }
                .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
    }

    private struct ResponsesOutputItem: Decodable {
        let content: [ResponsesContent]?
    }

    private struct ResponsesContent: Decodable {
        let text: String?
    }
}

public final class OllamaTalonLiteLLMCorrectionEngine: TalonLiteLLMCorrectionEngine {
    private let host: String
    private let model: String
    private let session: URLSession

    public init(host: String, model: String, session: URLSession = .shared) {
        self.host = host
        self.model = model
        self.session = session
    }

    public func correctToGrammar(_ transcript: String) async throws -> String {
        guard let url = URL(string: "\(host)/api/generate") else {
            throw DictatorError.talonPipelineFailed("llm_correction: invalid Ollama host")
        }

        let payload = GeneratePayload(
            model: model,
            prompt: "Whisper transcript (possibly incorrect):\n\(transcript)",
            system: OpenAITalonLiteLLMCorrectionEngine.instructions,
            stream: false
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(urlError.code)
            {
                throw DictatorError.networkUnavailable
            }
            throw DictatorError.talonPipelineFailed("llm_correction: \(String(describing: error))")
        }

        guard let http = response as? HTTPURLResponse else {
            throw DictatorError.talonPipelineFailed("llm_correction: invalid Ollama response")
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DictatorError.talonPipelineFailed("llm_correction: \(String(message.prefix(220)))")
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let output = decoded.response,
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw DictatorError.talonPipelineFailed("llm_correction: Ollama response did not include output text")
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct GeneratePayload: Encodable {
        let model: String
        let prompt: String
        let system: String
        let stream: Bool
    }

    private struct GenerateResponse: Decodable {
        let response: String?
    }
}

public struct TalonLitePipelineResult: Sendable, Equatable {
    public let rawTranscript: String
    public let grammarTranscript: String
    public let outputText: String
    public let wasLLMCorrected: Bool
    public let transcribeMs: Int
    public let pipelineMs: Int

    public init(
        rawTranscript: String,
        grammarTranscript: String,
        outputText: String,
        wasLLMCorrected: Bool,
        transcribeMs: Int,
        pipelineMs: Int
    ) {
        self.rawTranscript = rawTranscript
        self.grammarTranscript = grammarTranscript
        self.outputText = outputText
        self.wasLLMCorrected = wasLLMCorrected
        self.transcribeMs = transcribeMs
        self.pipelineMs = pipelineMs
    }
}

public final class TalonLitePipelineOrchestrator: Sendable {
    private let sttEngine: STTEngine
    private let correctionEngine: TalonLiteLLMCorrectionEngine
    private let trace: (@Sendable (String) -> Void)?

    public init(
        sttEngine: STTEngine,
        correctionEngine: TalonLiteLLMCorrectionEngine,
        trace: (@Sendable (String) -> Void)? = nil
    ) {
        self.sttEngine = sttEngine
        self.correctionEngine = correctionEngine
        self.trace = trace
    }

    public func process(_ request: TranscribeRequest) async throws -> TalonLitePipelineResult {
        let start = ContinuousClock.now
        let transcribeStart = ContinuousClock.now
        let transcribed = try await sttEngine.transcribe(request)
        let transcribeMs = transcribeStart.durationMs
        let rawTranscript = transcribed.raw_transcript
        let normalizedTranscript = Self.lettersOnlyTranscript(from: rawTranscript)
        trace?("talon-lite raw transcript: \(Self.logSafeText(rawTranscript))")
        trace?("talon-lite normalized transcript: \(Self.logSafeText(normalizedTranscript))")

        do {
            let ast = try TalonLiteGrammarParser.parse(normalizedTranscript)
            let rendered = try TalonLiteRenderer.render(ast)
            trace?("talon-lite parse/render success without correction")
            return TalonLitePipelineResult(
                rawTranscript: rawTranscript,
                grammarTranscript: normalizedTranscript,
                outputText: rendered,
                wasLLMCorrected: false,
                transcribeMs: transcribeMs,
                pipelineMs: start.durationMs
            )
        } catch let parseError as TalonLiteGrammarParseError {
            trace?("talon-lite parse failed before correction: \(parseError.message)")
            let corrected = try await correctionEngine.correctToGrammar(normalizedTranscript)
            trace?("talon-lite corrected transcript: \(Self.logSafeText(corrected))")

            let ast: TalonLiteAST
            do {
                ast = try TalonLiteGrammarParser.parse(corrected)
            } catch let reparseError as TalonLiteGrammarParseError {
                trace?("talon-lite reparse failed: \(reparseError.message)")
                throw DictatorError.talonPipelineFailed("reparse: \(reparseError.message)")
            }

            do {
                let rendered = try TalonLiteRenderer.render(ast)
                return TalonLitePipelineResult(
                    rawTranscript: rawTranscript,
                    grammarTranscript: corrected,
                    outputText: rendered,
                    wasLLMCorrected: true,
                    transcribeMs: transcribeMs,
                    pipelineMs: start.durationMs
                )
            } catch let error as DictatorError {
                throw error
            } catch {
                throw DictatorError.talonPipelineFailed("render: \(String(describing: error))")
            }
        } catch let error as DictatorError {
            throw error
        } catch {
            throw DictatorError.talonPipelineFailed("parse: \(String(describing: error))")
        }
    }

    private static func logSafeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func lettersOnlyTranscript(from input: String) -> String {
        let mapped = input.map { ch -> Character in
            if ch.isLetter || ch.isWhitespace {
                return ch
            }
            return " "
        }
        return String(mapped).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

private extension ContinuousClock.Instant {
    var durationMs: Int {
        let duration = ContinuousClock.now - self
        return Int(duration.components.seconds * 1000) + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
