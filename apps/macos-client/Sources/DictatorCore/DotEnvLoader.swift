import Darwin
import Foundation

public enum DotEnvLoader {
    @discardableResult
    public static func loadIntoProcessEnvironment(overrideExisting: Bool = true) -> [String: String] {
        guard let dotenvURL = discoverDotEnvURL() else {
            return [:]
        }

        guard let contents = try? String(contentsOf: dotenvURL, encoding: .utf8) else {
            return [:]
        }

        let parsed = parse(contents)
        for (key, value) in parsed {
            if !overrideExisting, ProcessInfo.processInfo.environment[key] != nil {
                continue
            }
            setenv(key, value, 1)
        }
        return parsed
    }

    static func parse(_ content: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in content.split(whereSeparator: \.isNewline) {
            var line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                continue
            }

            var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\""))
                   || (value.hasPrefix("'") && value.hasSuffix("'"))
            {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }
        return values
    }

    private static func discoverDotEnvURL() -> URL? {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<5 {
            let candidate = url.appendingPathComponent(".env")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        return nil
    }
}
