import Foundation

public struct SystemPromptCatalog {
    public static let defaultPromptFile = "intent_refiner_v1.md"

    private let directoryURL: URL
    private let fileManager: FileManager

    public init(
        directoryURL: URL = Self.defaultDirectoryURL(),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public static func defaultDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) -> URL {
        if let override = environment["DICTATOR_SYSTEM_PROMPTS_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let cwd = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        let direct = cwd.appendingPathComponent("prompts/system-prompts", isDirectory: true)
        if fileManager.fileExists(atPath: direct.path) {
            return direct
        }

        let nested = cwd
            .appendingPathComponent("../../prompts/system-prompts", isDirectory: true)
            .standardizedFileURL
        if fileManager.fileExists(atPath: nested.path) {
            return nested
        }

        return direct
    }

    public func listPromptFiles() throws -> [String] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return [Self.defaultPromptFile]
        }

        let entries = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let files = entries
            .filter { $0.hasDirectoryPath == false }
            .map(\.lastPathComponent)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()

        return files.isEmpty ? [Self.defaultPromptFile] : files
    }

    public func loadPrompt(named fileName: String) throws -> String {
        let sanitized = sanitizeFileName(fileName)
        let path = directoryURL.appendingPathComponent(sanitized)
        let content = try String(contentsOf: path, encoding: .utf8)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DictatorError.configUpdateFailed("system prompt file is empty: \(sanitized)")
        }
        return trimmed
    }

    public func resolvePrompt(named fileName: String) -> String {
        do {
            return try loadPrompt(named: fileName)
        } catch {
            return RefinementPromptBuilder.fallbackInstructions
        }
    }

    public func sanitizeFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Self.defaultPromptFile
        }
        return URL(fileURLWithPath: trimmed).lastPathComponent
    }
}
