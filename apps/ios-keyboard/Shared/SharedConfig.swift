import Foundation

enum SharedConfig {
    static let appGroupIdentifier = "group.com.joyo.dictator"
    static let fallbackServerURL = "http://192.168.1.12:8787"
    static let hostURLKey = "ios_client_host_url"

    static func resolvedServerURLString(bundle: Bundle = .main) -> String {
        if let raw = bundle.object(forInfoDictionaryKey: hostURLKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let raw = sharedDefaults.string(forKey: hostURLKey) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallbackServerURL
    }
}
