import Foundation
import XCTest
@testable import DictatorCore

final class SystemPromptCatalogTests: XCTestCase {
    func testLoadPromptReturnsFileContents() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let promptFile = tempDir.appendingPathComponent("intent_refiner_v1.md")
        try "hello".write(to: promptFile, atomically: true, encoding: .utf8)

        let catalog = SystemPromptCatalog(directoryURL: tempDir)
        XCTAssertEqual(try catalog.loadPrompt(named: "intent_refiner_v1.md"), "hello")
    }

    func testResolvePromptFallsBackWhenFileMissing() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let catalog = SystemPromptCatalog(directoryURL: tempDir)

        let resolved = catalog.resolvePrompt(named: "missing.md")
        XCTAssertEqual(resolved, RefinementPromptBuilder.fallbackInstructions)
    }

    private func makeTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
