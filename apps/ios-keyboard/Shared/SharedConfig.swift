import Foundation

enum SharedConfig {
    static let appGroupIdentifier = "group.com.joyo.dictator"
    static let fallbackServerURL = "http://192.168.1.56:8787"
    static let hostURLKey = "ios_client_host_url"
    static let latestTranscriptKey = "latest_transcript"
    static let latestTranscriptUpdatedAtKey = "latest_transcript_updated_at"
    static let diagnosticsFilename = "host_diagnostics.log"
    static let hostAppURLScheme = "dictatorkeyboardhost"
    static let hostAppLaunchURLString = "\(hostAppURLScheme)://open"

    static func resolvedServerURLString(bundle: Bundle = .main) -> String {
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let raw = sharedDefaults.string(forKey: hostURLKey) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let raw = bundle.object(forInfoDictionaryKey: hostURLKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallbackServerURL
    }

    static func saveServerURLString(_ value: String) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            sharedDefaults.removeObject(forKey: hostURLKey)
        } else {
            sharedDefaults.set(trimmed, forKey: hostURLKey)
        }
    }

    static func saveLatestTranscript(_ transcript: String, now: Date = Date()) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        sharedDefaults.set(transcript, forKey: latestTranscriptKey)
        sharedDefaults.set(now.timeIntervalSince1970, forKey: latestTranscriptUpdatedAtKey)
    }

    static func loadLatestTranscript() -> String? {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let transcript = sharedDefaults.string(forKey: latestTranscriptKey) else {
            return nil
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : transcript
    }

    static func loadLatestTranscriptUpdatedAt() -> Date? {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return nil
        }

        let timestamp = sharedDefaults.double(forKey: latestTranscriptUpdatedAtKey)
        guard timestamp > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func diagnosticsLogURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(diagnosticsFilename)
    }

    static func appendDiagnosticsLine(_ line: String) {
        guard let url = diagnosticsLogURL() else {
            return
        }

        let text = line + "\n"
        let data = Data(text.utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func readDiagnosticsLog() -> String? {
        guard let url = diagnosticsLogURL() else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func clearDiagnosticsLog() {
        guard let url = diagnosticsLogURL() else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

}
