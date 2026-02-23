import Foundation

public final class OpenAIRefinementEngine: RefinementEngine {
    private let model: String
    private let secretStore: SecretStore
    private let session: URLSession

    public init(model: String = "gpt-4.1-mini", secretStore: SecretStore, session: URLSession = .shared) {
        self.model = model
        self.secretStore = secretStore
        self.session = session
    }

    public func refine(_ request: RefineRequest) async throws -> RefineResponse {
        guard let key = try APIKeyResolver.resolve(fallback: { try secretStore.getOpenAIKey() }) else {
            throw DictatorError.missingApiKey
        }

        let payload = ResponsesPayload(
            model: model,
            instructions: Self.instructions,
            input: Self.buildInput(rawTranscript: request.raw_transcript, optionalContext: request.optional_context ?? [:])
        )
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(urlError.code)
            {
                throw DictatorError.networkUnavailable
            }
            throw DictatorError.refinementFailed(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw DictatorError.refinementFailed("Invalid server response")
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw DictatorError.invalidApiKey
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DictatorError.refinementFailed(String(message.prefix(220)))
        }

        let decoded = try JSONDecoder().decode(ResponsesOutput.self, from: data)
        guard let text = decoded.firstOutputText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw DictatorError.refinementFailed("OpenAI response did not include output text")
        }

        return RefineResponse(
            revised_text: text,
            edit_summary: "Refined with OpenAI model.",
            uncertainty_flags: []
        )
    }

    static func buildInput(rawTranscript: String, optionalContext: [String: String]) -> String {
        let selectedText = optionalContext["selected_text"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedText, !selectedText.isEmpty {
            return """
            Take the following input and modify it based on the following request.

            Input text:
            \(selectedText)

            Request:
            \(rawTranscript)
            """
        }

        var contextLines: [String] = []
        if let dictationContext = optionalContext["dictation_context"]?.trimmingCharacters(in: .whitespacesAndNewlines), !dictationContext.isEmpty {
            contextLines.append(dictationContext)
        }
        if let activeApp = optionalContext["active_app"]?.trimmingCharacters(in: .whitespacesAndNewlines), !activeApp.isEmpty {
            contextLines.append("Active app: \(activeApp)")
        }
        if let activeSite = optionalContext["active_site"]?.trimmingCharacters(in: .whitespacesAndNewlines), !activeSite.isEmpty {
            contextLines.append("Active site: \(activeSite)")
        }

        if contextLines.isEmpty {
            return rawTranscript
        }

        return "Context:\n" + contextLines.map { "- \($0)" }.joined(separator: "\n") + "\n\nTranscript:\n\(rawTranscript)"
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
            if let outputText = output_text, !outputText.isEmpty {
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

    private static let instructions = """
    You are an intent-preserving voice transcription refiner.

    Input context:
    - The user text comes from a full voice-to-text pipeline (Whisper + refinement).
    - Transcription may contain errors, missing punctuation, repeated words, or misheard phrases.

    Operating modes:
    1) Transcript refinement mode (default): improve transcript quality while preserving meaning.
    2) Selected-text transform mode: when optional context includes selected input text, treat transcript as the user's modification request for that selected text.

    Your task:
    1) Rewrite the text to reflect the speaker's intended meaning, not just literal transcript wording.
    2) Correct likely transcription errors, grammar, punctuation, and clarity issues.
    3) Preserve tone and important details, but remove obvious filler, false starts, and rambling when they do not add meaning.
    4) If the speaker changes their mind (e.g., 'I thought X, but actually Y'), prioritize the final decision/intent (Y) in the refined output.
    5) When earlier and later statements conflict, treat later statements as updates unless the speaker explicitly says both should be kept.
    6) Do not invent facts. If meaning is ambiguous, produce the most likely interpretation and keep wording neutral.

    Conflict resolution rule:
    - If a statement includes a correction, reversal, or preference update ('actually', 'instead', 'rather', 'on second thought', 'change that'), treat it as the active intent and de-emphasize superseded wording.

    Context usage rule:
    - Optional context may indicate the active dictation target (app/site/coding-agent hint). Use it to disambiguate wording and intent, but do not invent facts.
    - If selected input text is provided in context, apply the spoken request to that selected text.

    Output format:
    - Return only the final output text for the active mode.
    - Do not include explanations, notes, or meta-commentary unless explicitly requested.
    """
}
