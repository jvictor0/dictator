import Foundation

public struct RuntimeConfigFile: Codable, Sendable, Equatable {
    public let version: Int
    public let cloudModel: String
    public let localModel: String
    public let useCloud: Bool
    public let updatedAt: String

    public var model: String {
        useCloud ? cloudModel : localModel
    }

    public init(
        version: Int = 2,
        cloudModel: String,
        localModel: String,
        useCloud: Bool,
        updatedAt: String
    ) {
        self.version = version
        self.cloudModel = cloudModel
        self.localModel = localModel
        self.useCloud = useCloud
        self.updatedAt = updatedAt
    }

    public init(version: Int = 1, model: String, useCloud: Bool, updatedAt: String) {
        self.init(
            version: version,
            cloudModel: model,
            localModel: model,
            useCloud: useCloud,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case version
        case model
        case cloudModel = "cloud_model"
        case localModel = "local_model"
        case useCloud = "use_cloud"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        let useCloud = try container.decode(Bool.self, forKey: .useCloud)
        let updatedAt = try container.decode(String.self, forKey: .updatedAt)

        let cloudModel = try container.decodeIfPresent(String.self, forKey: .cloudModel)
        let localModel = try container.decodeIfPresent(String.self, forKey: .localModel)
        let legacyModel = try container.decodeIfPresent(String.self, forKey: .model)

        let resolvedCloudModel = cloudModel ?? legacyModel ?? "gpt-4.1-mini"
        let resolvedLocalModel = localModel ?? legacyModel ?? "qwen2.5:7b-instruct"

        self.init(
            version: version,
            cloudModel: resolvedCloudModel,
            localModel: resolvedLocalModel,
            useCloud: useCloud,
            updatedAt: updatedAt
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(cloudModel, forKey: .cloudModel)
        try container.encode(localModel, forKey: .localModel)
        try container.encode(useCloud, forKey: .useCloud)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static func bootstrap(from configuration: LLMRuntimeConfiguration, now: Date = Date()) -> RuntimeConfigFile {
        RuntimeConfigFile(
            version: 2,
            cloudModel: configuration.openAIModel,
            localModel: configuration.ollamaModel,
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
    public let cloudModel: String?
    public let localModel: String?
    public let useCloud: Bool?

    public init(
        model: String? = nil,
        cloudModel: String? = nil,
        localModel: String? = nil,
        useCloud: Bool? = nil
    ) {
        self.model = model
        self.cloudModel = cloudModel
        self.localModel = localModel
        self.useCloud = useCloud
    }

    var isEmpty: Bool {
        model == nil && cloudModel == nil && localModel == nil && useCloud == nil
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
    private let defaultConfig: RuntimeConfigFile
    private var runtimeConfig: RuntimeConfigFile

    public init(
        store: RuntimeConfigStore = RuntimeConfigStore(fileURL: RuntimeConfigStore.defaultFileURL()),
        defaultStore: RuntimeConfigStore? = RuntimeConfigStore(fileURL: RuntimeConfigStore.defaultSafeFileURL()),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.store = store
        self.environment = environment

        let baseConfiguration = LLMRuntimeConfiguration.fromEnvironment(environment)
        let defaultFromSafe = try? defaultStore?.load()
        let startupDefault = defaultFromSafe ?? RuntimeConfigFile.bootstrap(from: baseConfiguration)
        self.defaultConfig = startupDefault

        let loaded = try? store.load()
        let initialConfig = loaded ?? startupDefault
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

    public func startupDefaultConfig() -> RuntimeConfigFile {
        defaultConfig
    }

    @discardableResult
    public func applyPatch(_ patch: RuntimeConfigPatch, now: Date = Date()) throws -> RuntimeConfigFile {
        let next = try resolvedConfig(for: patch, now: now)

        do {
            try store.save(next)
        } catch {
            throw DictatorError.configUpdateFailed("failed to persist runtime config: \(error)")
        }

        runtimeConfig = next
        return next
    }

    @discardableResult
    public func applyInMemoryPatch(_ patch: RuntimeConfigPatch, now: Date = Date()) throws -> RuntimeConfigFile {
        let next = try resolvedConfig(for: patch, now: now)
        runtimeConfig = next
        return next
    }

    private func resolvedConfig(for patch: RuntimeConfigPatch, now: Date) throws -> RuntimeConfigFile {
        if patch.isEmpty {
            throw DictatorError.configUpdateFailed("refusing empty config patch")
        }

        let resolvedUseCloud = patch.useCloud ?? runtimeConfig.useCloud
        let patchedModel = patch.model?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCloudModel = (patch.cloudModel?.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? (resolvedUseCloud ? (patchedModel ?? runtimeConfig.cloudModel) : runtimeConfig.cloudModel)
        let resolvedLocalModel = (patch.localModel?.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? (resolvedUseCloud ? runtimeConfig.localModel : (patchedModel ?? runtimeConfig.localModel))

        if resolvedCloudModel.isEmpty {
            throw DictatorError.configUpdateFailed("cloud model cannot be empty")
        }
        if resolvedLocalModel.isEmpty {
            throw DictatorError.configUpdateFailed("local model cannot be empty")
        }

        let next = RuntimeConfigFile(
            version: runtimeConfig.version,
            cloudModel: resolvedCloudModel,
            localModel: resolvedLocalModel,
            useCloud: resolvedUseCloud,
            updatedAt: RuntimeConfigFile.timestamp(from: now)
        )
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
