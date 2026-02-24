import Foundation

public struct RuntimeConfigFile: Codable, Sendable, Equatable {
    public let version: Int
    public let model: String
    public let useCloud: Bool
    public let updatedAt: String

    public init(version: Int = 1, model: String, useCloud: Bool, updatedAt: String) {
        self.version = version
        self.model = model
        self.useCloud = useCloud
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case version
        case model
        case useCloud = "use_cloud"
        case updatedAt = "updated_at"
    }

    static func bootstrap(from configuration: LLMRuntimeConfiguration, now: Date = Date()) -> RuntimeConfigFile {
        RuntimeConfigFile(
            version: 1,
            model: configuration.provider == .openai ? configuration.openAIModel : configuration.ollamaModel,
            useCloud: configuration.provider == .openai,
            updatedAt: Self.timestamp(from: now)
        )
    }

    static func timestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

public struct RuntimeConfigPatch: Sendable, Equatable {
    public let model: String?
    public let useCloud: Bool?

    public init(model: String? = nil, useCloud: Bool? = nil) {
        self.model = model
        self.useCloud = useCloud
    }

    var isEmpty: Bool {
        model == nil && useCloud == nil
    }
}

public struct RuntimeConfigStore {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static func defaultFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) -> URL {
        if let override = environment["DICTATOR_RUNTIME_CONFIG_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let cwd = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        let direct = cwd.appendingPathComponent("Config/runtime-config.json")
        if fileManager.fileExists(atPath: direct.deletingLastPathComponent().path) {
            return direct
        }

        let nested = cwd.appendingPathComponent("apps/macos-client/Config/runtime-config.json")
        if fileManager.fileExists(atPath: nested.deletingLastPathComponent().path) {
            return nested
        }

        return direct
    }

    public static func defaultSafeFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) -> URL {
        if let override = environment["DICTATOR_RUNTIME_CONFIG_SAFE_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let cwd = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        let direct = cwd.appendingPathComponent("Config/runtime-config.safe")
        if fileManager.fileExists(atPath: direct.deletingLastPathComponent().path) {
            return direct
        }

        let nested = cwd.appendingPathComponent("apps/macos-client/Config/runtime-config.safe")
        if fileManager.fileExists(atPath: nested.deletingLastPathComponent().path) {
            return nested
        }

        return direct
    }

    public func load() throws -> RuntimeConfigFile? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(RuntimeConfigFile.self, from: data)
    }

    public func save(_ config: RuntimeConfigFile) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let tmpURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)

        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
        } else {
            try fileManager.moveItem(at: tmpURL, to: fileURL)
        }
    }
}

public actor RuntimeConfigProvider {
    private let store: RuntimeConfigStore
    private let environment: [String: String]
    private var runtimeConfig: RuntimeConfigFile

    public init(
        store: RuntimeConfigStore = RuntimeConfigStore(fileURL: RuntimeConfigStore.defaultFileURL()),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.store = store
        self.environment = environment

        let baseConfiguration = LLMRuntimeConfiguration.fromEnvironment(environment)
        let loaded = try? store.load()
        let initialConfig = loaded ?? RuntimeConfigFile.bootstrap(from: baseConfiguration)
        if loaded == nil {
            try? store.save(initialConfig)
        }
        self.runtimeConfig = initialConfig
    }

    public func currentRuntimeConfig() -> RuntimeConfigFile {
        runtimeConfig
    }

    public func currentConfiguration() -> LLMRuntimeConfiguration {
        LLMRuntimeConfiguration.fromEnvironment(environment, runtimeOverride: runtimeConfig)
    }

    @discardableResult
    public func applyPatch(_ patch: RuntimeConfigPatch, now: Date = Date()) throws -> RuntimeConfigFile {
        if patch.isEmpty {
            throw DictatorError.configUpdateFailed("refusing empty config patch")
        }

        let resolvedModel = patch.model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? runtimeConfig.model
        if resolvedModel.isEmpty {
            throw DictatorError.configUpdateFailed("model cannot be empty")
        }

        let next = RuntimeConfigFile(
            version: runtimeConfig.version,
            model: resolvedModel,
            useCloud: patch.useCloud ?? runtimeConfig.useCloud,
            updatedAt: RuntimeConfigFile.timestamp(from: now)
        )

        do {
            try store.save(next)
        } catch {
            throw DictatorError.configUpdateFailed("failed to persist runtime config: \(error)")
        }

        runtimeConfig = next
        return next
    }

    public func reloadFromDisk() throws {
        guard let loaded = try store.load() else {
            return
        }
        runtimeConfig = loaded
    }

    @discardableResult
    public func loadFromStoreIntoMemory(_ sourceStore: RuntimeConfigStore) throws -> RuntimeConfigFile {
        guard let loaded = try sourceStore.load() else {
            throw DictatorError.configUpdateFailed("safe runtime config file is missing")
        }
        runtimeConfig = loaded
        return loaded
    }
}
