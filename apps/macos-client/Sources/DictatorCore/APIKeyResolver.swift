import Foundation

public enum APIKeyResolver {
    private static let environmentKeyOrder = [
        "DICTATOR_OPENAI_API_KEY",
        "OPENAI_API_KEY"
    ]

    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallback: () throws -> String?
    ) rethrows -> String? {
        if let envKey = environmentValue(environment), !envKey.isEmpty {
            return envKey
        }

        guard let fallbackKey = try fallback() else {
            return nil
        }
        let normalized = fallbackKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    public static func environmentValue(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        for key in environmentKeyOrder {
            guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                continue
            }
            return value
        }
        return nil
    }
}
