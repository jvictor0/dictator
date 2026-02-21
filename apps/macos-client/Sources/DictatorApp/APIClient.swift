import Foundation

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

public enum APIClientError: Error {
    case badStatus(Int)
}

public final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func dictate(_ payload: DictateRequest) async throws -> DictateResponse {
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
        return try JSONDecoder().decode(DictateResponse.self, from: data)
    }

    public static func decodeDictateResponse(from data: Data) throws -> DictateResponse {
        try JSONDecoder().decode(DictateResponse.self, from: data)
    }
}
