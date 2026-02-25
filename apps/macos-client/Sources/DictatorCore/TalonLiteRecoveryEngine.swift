import Foundation

public struct TalonLiteRecoveryDecision: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case recovered
        case cannotRecover = "cannot_recover"
    }

    public let kind: Kind
    public let transcript: String?

    public init(kind: Kind, transcript: String? = nil) {
        self.kind = kind
        self.transcript = transcript
    }
}

public enum TalonLiteRecoveryDecisionParser {
    public static func parse(_ rawJSON: String) throws -> TalonLiteRecoveryDecision {
        guard let data = rawJSON.data(using: .utf8) else {
            throw DictatorError.talonRecoveryFailed("recovery payload is not valid JSON")
        }
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DictatorError.talonRecoveryFailed("recovery payload is not valid JSON")
        }
        guard let json = jsonObject as? [String: Any] else {
            throw DictatorError.talonRecoveryFailed("recovery payload is not valid JSON")
        }

        let allowedKeys: Set<String> = ["decision", "transcript"]
        let unknownKeys = Set(json.keys).subtracting(allowedKeys)
        if !unknownKeys.isEmpty {
            throw DictatorError.talonRecoveryFailed("recovery payload contains unsupported keys: \(unknownKeys.sorted())")
        }

        guard let rawDecision = json["decision"] as? String,
              let kind = TalonLiteRecoveryDecision.Kind(rawValue: rawDecision)
        else {
            throw DictatorError.talonRecoveryFailed("recovery decision must be recovered/cannot_recover")
        }

        switch kind {
        case .cannotRecover:
            if json["transcript"] != nil {
                throw DictatorError.talonRecoveryFailed("transcript must be omitted when decision=cannot_recover")
            }
            return TalonLiteRecoveryDecision(kind: .cannotRecover)
        case .recovered:
            guard let transcript = json["transcript"] as? String else {
                throw DictatorError.talonRecoveryFailed("transcript is required when decision=recovered")
            }
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw DictatorError.talonRecoveryFailed("transcript cannot be empty when decision=recovered")
            }
            return TalonLiteRecoveryDecision(kind: .recovered, transcript: trimmed)
        }
    }
}

public protocol TalonLiteRecoveryEngine: Sendable {
    func recoverTranscript(_ transcript: String) async throws -> TalonLiteRecoveryDecision
}

public final class RuntimeConfigTalonLiteRecoveryEngine: TalonLiteRecoveryEngine {
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

    public func recoverTranscript(_ transcript: String) async throws -> TalonLiteRecoveryDecision {
        let configuration = await runtimeConfigProvider.currentConfiguration()

        let ollamaEngine = OllamaTalonLiteRecoveryEngine(
            host: configuration.ollamaHost,
            model: configuration.ollamaModel,
            session: session
        )
        let openAIEngine = OpenAITalonLiteRecoveryEngine(
            model: configuration.openAIModel,
            secretStore: secretStore,
            session: session
        )

        switch configuration.provider {
        case .openai:
            return try await openAIEngine.recoverTranscript(transcript)
        case .ollama:
            do {
                return try await ollamaEngine.recoverTranscript(transcript)
            } catch {
                guard configuration.fallback == .openai, canUseOpenAI() else {
                    throw error
                }
                return try await openAIEngine.recoverTranscript(transcript)
            }
        }
    }
}

public final class OpenAITalonLiteRecoveryEngine: TalonLiteRecoveryEngine {
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

    public func recoverTranscript(_ transcript: String) async throws -> TalonLiteRecoveryDecision {
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
            throw DictatorError.talonRecoveryFailed(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw DictatorError.talonRecoveryFailed("invalid server response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw DictatorError.invalidApiKey
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DictatorError.talonRecoveryFailed(String(message.prefix(220)))
        }

        let decoded = try JSONDecoder().decode(ResponsesOutput.self, from: data)
        guard let output = decoded.firstOutputText else {
            throw DictatorError.talonRecoveryFailed("OpenAI response did not include output text")
        }

        return try TalonLiteRecoveryDecisionParser.parse(output)
    }

    private static func input(transcript: String) -> String {
        """
        Whisper transcript (possibly wrong):
        \(transcript)
        """
    }

    static let instructions = """
    You are a Talon parser.
    \(TalonLiteParser.grammarText)

    This text came from Whisper and may contain transcription errors. Correct it into the closest valid Talon-lite utterance.

    Rules:
    - Only use tokens allowed by the grammar.
    - Output must be strict JSON and nothing else.
    - Allowed JSON outputs:
      {"decision":"recovered","transcript":"<corrected utterance>"}
      {"decision":"cannot_recover"}
    - If ambiguous or not confidently recoverable, return cannot_recover.
    """

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

public final class OllamaTalonLiteRecoveryEngine: TalonLiteRecoveryEngine {
    private let host: String
    private let model: String
    private let session: URLSession

    public init(host: String, model: String, session: URLSession = .shared) {
        self.host = host
        self.model = model
        self.session = session
    }

    public func recoverTranscript(_ transcript: String) async throws -> TalonLiteRecoveryDecision {
        guard let url = URL(string: "\(host)/api/generate") else {
            throw DictatorError.talonRecoveryFailed("invalid Ollama host")
        }

        let payload = GeneratePayload(
            model: model,
            prompt: "Whisper transcript (possibly wrong):\n\(transcript)",
            system: OpenAITalonLiteRecoveryEngine.instructions,
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
            throw DictatorError.talonRecoveryFailed(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw DictatorError.talonRecoveryFailed("invalid Ollama response")
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DictatorError.talonRecoveryFailed(String(message.prefix(220)))
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let output = decoded.response,
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw DictatorError.talonRecoveryFailed("Ollama response did not include output text")
        }

        return try TalonLiteRecoveryDecisionParser.parse(output)
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

public struct TalonLiteProcessResult: Sendable, Equatable {
    public let rawTranscript: String
    public let outputText: String
    public let style: TalonLiteStyle
    public let recoveredTranscript: String?
    public let transcribeMs: Int
    public let parseAndRecoveryMs: Int

    public init(
        rawTranscript: String,
        outputText: String,
        style: TalonLiteStyle,
        recoveredTranscript: String?,
        transcribeMs: Int,
        parseAndRecoveryMs: Int
    ) {
        self.rawTranscript = rawTranscript
        self.outputText = outputText
        self.style = style
        self.recoveredTranscript = recoveredTranscript
        self.transcribeMs = transcribeMs
        self.parseAndRecoveryMs = parseAndRecoveryMs
    }
}

public final class TalonLiteOrchestrator: Sendable {
    private let sttEngine: STTEngine
    private let recoveryEngine: TalonLiteRecoveryEngine
    private let trace: (@Sendable (String) -> Void)?

    public init(
        sttEngine: STTEngine,
        recoveryEngine: TalonLiteRecoveryEngine,
        trace: (@Sendable (String) -> Void)? = nil
    ) {
        self.sttEngine = sttEngine
        self.recoveryEngine = recoveryEngine
        self.trace = trace
    }

    public func process(_ request: TranscribeRequest) async throws -> TalonLiteProcessResult {
        let transcribeStart = ContinuousClock.now
        let transcribed = try await sttEngine.transcribe(request)
        let transcribeMs = transcribeStart.durationMs
        let rawTranscript = transcribed.raw_transcript
        trace?("talon-lite raw transcript: \(Self.logSafeText(rawTranscript))")
        let parseStart = ContinuousClock.now

        do {
            let parsed = try TalonLiteParser.parse(rawTranscript)
            trace?("talon-lite parse success style=\(parsed.style.rawValue) output=\(Self.logSafeText(parsed.outputText))")
            return TalonLiteProcessResult(
                rawTranscript: rawTranscript,
                outputText: parsed.outputText,
                style: parsed.style,
                recoveredTranscript: nil,
                transcribeMs: transcribeMs,
                parseAndRecoveryMs: parseStart.durationMs
            )
        } catch let parseError as TalonLiteParseError where parseError.isRecoverableUnknownToken {
            trace?("talon-lite parse recoverable failure reason=\(parseError.message)")
            let recovery = try await recoveryEngine.recoverTranscript(rawTranscript)
            trace?("talon-lite recovery decision=\(recovery.kind.rawValue)")
            guard recovery.kind == .recovered,
                  let corrected = recovery.transcript
            else {
                throw DictatorError.talonRecoveryFailed("recovery model could not determine valid Talon tokens")
            }
            trace?("talon-lite recovered transcript: \(Self.logSafeText(corrected))")

            do {
                let reparsed = try TalonLiteParser.parse(corrected)
                trace?("talon-lite reparse success style=\(reparsed.style.rawValue) output=\(Self.logSafeText(reparsed.outputText))")
                return TalonLiteProcessResult(
                    rawTranscript: rawTranscript,
                    outputText: reparsed.outputText,
                    style: reparsed.style,
                    recoveredTranscript: corrected,
                    transcribeMs: transcribeMs,
                    parseAndRecoveryMs: parseStart.durationMs
                )
            } catch let secondParseError as TalonLiteParseError {
                trace?("talon-lite reparse failed reason=\(secondParseError.message)")
                throw DictatorError.talonRecoveryFailed("recovered transcript is still invalid: \(secondParseError.message)")
            }
        } catch let parseError as TalonLiteParseError {
            trace?("talon-lite parse terminal failure reason=\(parseError.message)")
            throw DictatorError.talonParseFailed(parseError.message)
        }
    }

    private static func logSafeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }
}

private extension ContinuousClock.Instant {
    var durationMs: Int {
        let duration = ContinuousClock.now - self
        return Int(duration.components.seconds * 1000) + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
