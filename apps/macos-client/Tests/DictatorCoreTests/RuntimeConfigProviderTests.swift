import Foundation
import XCTest
@testable import DictatorCore

final class RuntimeConfigProviderTests: XCTestCase {
    func testRuntimeConfigOverridesEnvironment() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("runtime-config.json")
        let seed = RuntimeConfigFile(version: 1, model: "gpt-4.1", useCloud: true, updatedAt: "2026-02-23T00:00:00Z")
        try RuntimeConfigStore(fileURL: fileURL).save(seed)

        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: fileURL),
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

        let primary = RuntimeConfigFile(version: 1, model: "gpt-4o-mini", useCloud: true, updatedAt: "2026-02-24T00:00:00Z")
        let safe = RuntimeConfigFile(version: 1, model: "qwen2.5:7b-instruct", useCloud: false, updatedAt: "2026-02-24T00:05:00Z")

        let primaryStore = RuntimeConfigStore(fileURL: primaryURL)
        let safeStore = RuntimeConfigStore(fileURL: safeURL)
        try primaryStore.save(primary)
        try safeStore.save(safe)

        let provider = RuntimeConfigProvider(store: primaryStore, environment: [:])
        let loaded = try await provider.loadFromStoreIntoMemory(safeStore)
        XCTAssertEqual(loaded, safe)

        let inMemory = await provider.currentRuntimeConfig()
        XCTAssertEqual(inMemory, safe)

        let primaryPersisted = try XCTUnwrap(try primaryStore.load())
        XCTAssertEqual(primaryPersisted, primary)
    }

    private func makeTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
