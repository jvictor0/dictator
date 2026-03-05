import Foundation

enum TraceLogger {
    private static let logURL = URL(fileURLWithPath: "/tmp/dictator-trace.log")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func reset() {
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
        log("trace reset")
    }

    static func log(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }

        fputs(line, stderr)
    }

    static var path: String {
        logURL.path
    }
}
