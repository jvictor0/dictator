import Foundation
import XCTest
@testable import DictatorCore

final class RuntimeConfigProviderTests: XCTestCase {
    func testRuntimeConfigOverridesEnvironment() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("runtime-config.json")
        let seed = RuntimeConfigFile(
            version: 2,
            cloudModel: "gpt-4.1",
            localModel: "qwen2.5:7b-instruct",
            useCloud: true,
            updatedAt: "2026-02-23T00:00:00Z"
        )
        try RuntimeConfigStore(fileURL: fileURL).save(seed)

        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: fileURL),
            defaultStore: nil,
            environment: [
                "DICTATOR_LLM_PROVIDER": "ollama",
                "DICTATOR_OLLAMA_MODEL": "qwen2.5:7b-instruct",
                "OPENAI_MODEL": "gpt-4.1-mini"
            ]
        )

        let config = await provider.currentConfiguration()
        XCTAssertEqual(config.provider, .openai)
        XCTAssertEqual(config.openAIModel, "gpt-4.1")
        XCTAssertEqual(config.ollamaModel, "qwen2.5:7b-instruct")
    }

    func testApplyPatchPersistsAndImmediatelyAffectsEffectiveConfig() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("runtime-config.json")
        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: fileURL),
            defaultStore: nil,
            environment: [
                "DICTATOR_LLM_PROVIDER": "ollama",
                "DICTATOR_OLLAMA_MODEL": "qwen2.5:7b-instruct",
                "OPENAI_MODEL": "gpt-4.1-mini"
            ]
        )

        _ = try await provider.applyPatch(RuntimeConfigPatch(model: "gpt-4.1-mini", useCloud: true))

        let config = await provider.currentConfiguration()
        XCTAssertEqual(config.provider, .openai)
        XCTAssertEqual(config.openAIModel, "gpt-4.1-mini")

        let persisted = try XCTUnwrap(try RuntimeConfigStore(fileURL: fileURL).load())
        XCTAssertEqual(persisted.model, "gpt-4.1-mini")
        XCTAssertTrue(persisted.useCloud)
    }

    func testLoadFromStoreIntoMemoryDoesNotOverwritePrimaryFile() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let primaryURL = tempDir.appendingPathComponent("runtime-config.json")
        let safeURL = tempDir.appendingPathComponent("runtime-config.safe")

        let primary = RuntimeConfigFile(
            version: 2,
            cloudModel: "gpt-4o-mini",
            localModel: "qwen2.5:7b-instruct",
            useCloud: true,
            updatedAt: "2026-02-24T00:00:00Z"
        )
        let safe = RuntimeConfigFile(
            version: 2,
            cloudModel: "gpt-4.1-mini",
            localModel: "qwen2.5:7b-instruct",
            useCloud: false,
            updatedAt: "2026-02-24T00:05:00Z"
        )

        let primaryStore = RuntimeConfigStore(fileURL: primaryURL)
        let safeStore = RuntimeConfigStore(fileURL: safeURL)
        try primaryStore.save(primary)
        try safeStore.save(safe)

        let provider = RuntimeConfigProvider(store: primaryStore, defaultStore: nil, environment: [:])
        let loaded = try await provider.loadFromStoreIntoMemory(safeStore)
        XCTAssertEqual(loaded, safe)

        let inMemory = await provider.currentRuntimeConfig()
        XCTAssertEqual(inMemory, safe)

        let primaryPersisted = try XCTUnwrap(try primaryStore.load())
        XCTAssertEqual(primaryPersisted, primary)
    }

    func testStartupDefaultsComeFromSafeStoreWhenPrimaryMissing() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let primaryURL = tempDir.appendingPathComponent("runtime-config.json")
        let safeURL = tempDir.appendingPathComponent("runtime-config.safe")

        let safe = RuntimeConfigFile(
            version: 2,
            cloudModel: "gpt-4.1-mini",
            localModel: "qwen2.5:7b-instruct",
            useCloud: false,
            updatedAt: "2026-02-24T00:05:00Z"
        )
        try RuntimeConfigStore(fileURL: safeURL).save(safe)

        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: primaryURL),
            defaultStore: RuntimeConfigStore(fileURL: safeURL),
            environment: [
                "DICTATOR_LLM_PROVIDER": "openai",
                "OPENAI_MODEL": "gpt-4.1-mini"
            ]
        )

        let startupDefault = await provider.startupDefaultConfig()
        XCTAssertEqual(startupDefault, safe)

        let current = await provider.currentRuntimeConfig()
        XCTAssertEqual(current, safe)
    }

    func testApplyInMemoryPatchDoesNotPersistToPrimaryFile() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let primaryURL = tempDir.appendingPathComponent("runtime-config.json")
        let primary = RuntimeConfigFile(
            version: 2,
            cloudModel: "gpt-4.1-mini",
            localModel: "qwen2.5:7b-instruct",
            useCloud: true,
            updatedAt: "2026-02-24T00:00:00Z"
        )
        let primaryStore = RuntimeConfigStore(fileURL: primaryURL)
        try primaryStore.save(primary)

        let provider = RuntimeConfigProvider(store: primaryStore, defaultStore: nil, environment: [:])
        let updated = try await provider.applyInMemoryPatch(RuntimeConfigPatch(model: "qwen2.5:7b-instruct", useCloud: false))
        XCTAssertEqual(updated.model, "qwen2.5:7b-instruct")
        XCTAssertFalse(updated.useCloud)
        XCTAssertEqual(updated.localModel, "qwen2.5:7b-instruct")
        XCTAssertEqual(updated.cloudModel, "gpt-4.1-mini")

        let inMemory = await provider.currentRuntimeConfig()
        XCTAssertEqual(inMemory.model, "qwen2.5:7b-instruct")
        XCTAssertFalse(inMemory.useCloud)

        let persisted = try XCTUnwrap(try primaryStore.load())
        XCTAssertEqual(persisted, primary)
    }

    func testRuntimeConfigDefaultsInteractionsBufferToOneHundredMBWhenMissing() throws {
        let json = """
        {
          "version": 2,
          "cloud_model": "gpt-4.1-mini",
          "local_model": "qwen2.5:7b-instruct",
          "system_prompt": "intent_refiner_v1.md",
          "use_cloud": false,
          "updated_at": "2026-02-24T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(RuntimeConfigFile.self, from: json)
        XCTAssertEqual(decoded.interactionsBufferBytes, RuntimeConfigFile.defaultInteractionsBufferBytes)
    }

    func testApplyInMemoryPatchUpdatesInteractionsBufferBytes() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let primaryURL = tempDir.appendingPathComponent("runtime-config.json")
        let primaryStore = RuntimeConfigStore(fileURL: primaryURL)
        let provider = RuntimeConfigProvider(store: primaryStore, defaultStore: nil, environment: [:])

        let updated = try await provider.applyInMemoryPatch(
            RuntimeConfigPatch(interactionsBufferBytes: 25 * 1024 * 1024)
        )

        XCTAssertEqual(updated.interactionsBufferBytes, 25 * 1024 * 1024)
    }

    private func makeTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
