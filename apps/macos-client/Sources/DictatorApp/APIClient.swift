import Foundation

public struct TranscribeRequest: Codable {
    public let audio_b64: String
    public let sample_rate: Int
    public let locale: String
    public let session_id: String

    public init(audio_b64: String, sample_rate: Int, locale: String, session_id: String) {
        self.audio_b64 = audio_b64
        self.sample_rate = sample_rate
        self.locale = locale
        self.session_id = session_id
    }
}

public struct TranscribeSegment: Codable {
    public let start_ms: Int
    public let end_ms: Int
    public let text: String
}

public struct TranscribeResponse: Codable {
    public let raw_transcript: String
    public let segments: [TranscribeSegment]
    public let confidence: Double
    public let duration_ms: Int
}

public struct DictateRequest: Codable {
    public let audio_b64: String
    public let sample_rate: Int
    public let locale: String
    public let session_id: String
    public let optional_context: [String: String]?
    public let style_prefs: [String: String]?

    public init(
        audio_b64: String,
        sample_rate: Int,
        locale: String,
        session_id: String,
        optional_context: [String: String]? = nil,
        style_prefs: [String: String]? = nil
    ) {
        self.audio_b64 = audio_b64
        self.sample_rate = sample_rate
        self.locale = locale
        self.session_id = session_id
        self.optional_context = optional_context
        self.style_prefs = style_prefs
    }
}

public struct DictateResponse: Codable {
    public let raw_transcript: String
    public let revised_text: String
    public let edit_summary: String
    public let uncertainty_flags: [String]
}

public struct DictateCallResult {
    public let response: DictateResponse
    public let transcribeMs: Int?
    public let refineMs: Int?
}

public enum APIClientError: Error {
    case badStatus(Int)
    case emptyTranscript
}

public final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public var baseURLDescription: String {
        baseURL.absoluteString
    }

    public func dictate(_ payload: DictateRequest) async throws -> DictateCallResult {
        var request = URLRequest(url: baseURL.appending(path: "/v1/dictate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIClientError.badStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(DictateResponse.self, from: data)
        let transcribeMs = Int(http.value(forHTTPHeaderField: "X-Dictator-Transcribe-Ms") ?? "")
        let refineMs = Int(http.value(forHTTPHeaderField: "X-Dictator-Refine-Ms") ?? "")
        return DictateCallResult(response: decoded, transcribeMs: transcribeMs, refineMs: refineMs)
    }

    public func transcribe(_ payload: TranscribeRequest) async throws -> TranscribeResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/transcribe"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIClientError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TranscribeResponse.self, from: data)
        if decoded.raw_transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIClientError.emptyTranscript
        }
        return decoded
    }

    public static func decodeDictateResponse(from data: Data) throws -> DictateResponse {
        try JSONDecoder().decode(DictateResponse.self, from: data)
    }

    public static func decodeTranscribeResponse(from data: Data) throws -> TranscribeResponse {
        try JSONDecoder().decode(TranscribeResponse.self, from: data)
    }
}
