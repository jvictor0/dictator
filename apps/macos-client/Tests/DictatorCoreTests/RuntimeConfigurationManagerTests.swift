import Foundation
import XCTest
@testable import DictatorCore

final class RuntimeConfigurationManagerTests: XCTestCase {
    override func tearDown() {
        URLProtocol.unregisterClass(RuntimeConfigurationURLProtocolStub.self)
        super.tearDown()
    }

    func testListUsesOllamaTagsEndpointForModelOptions() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: tempDir.appendingPathComponent("runtime-config.json")),
            defaultStore: nil,
            environment: [:]
        )
        let session = makeSession()
        RuntimeConfigurationURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11434/api/tags")
            let data = #"{"models":[{"name":"qwen2.5:7b-instruct"},{"name":"llama3.2"}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let manager = RuntimeConfigurationManager(
            configurations: [
                RuntimeModelConfiguration(
                    name: "Local Model",
                    currentValue: "qwen2.5:7b-instruct",
                    defaultValue: "qwen2.5:7b-instruct",
                    target: .local,
                    optionsSource: .ollama,
                    runtimeConfigProvider: provider,
                    host: "http://127.0.0.1:11434",
                    session: session
                ),
                RuntimeBooleanConfiguration(
                    name: "Use Cloud",
                    currentValue: false,
                    defaultValue: false,
                    runtimeConfigProvider: provider
                )
            ]
        )

        let listed = try await manager.list()
        let model = try XCTUnwrap(listed.first(where: { $0.name == "Local Model" }))
        XCTAssertTrue(model.options.isEmpty)

        let options = try await manager.getOptions(name: "Local Model")
        XCTAssertEqual(options, [.string("qwen2.5:7b-instruct"), .string("llama3.2")])
    }

    func testResetToDefaultsUpdatesRuntimeConfigInMemory() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("runtime-config.json")
        let provider = RuntimeConfigProvider(
            store: RuntimeConfigStore(fileURL: fileURL),
            defaultStore: nil,
            environment: [:]
        )

        _ = try await provider.applyInMemoryPatch(
            RuntimeConfigPatch(model: "llama3.2", useCloud: true)
        )

        let manager = RuntimeConfigurationManager(
            configurations: [
                RuntimeModelConfiguration(
                    name: "Local Model",
                    currentValue: "llama3.2",
                    defaultValue: "qwen2.5:7b-instruct",
                    target: .local,
                    optionsSource: .ollama,
                    runtimeConfigProvider: provider,
                    host: "http://127.0.0.1:11434",
                    session: makeStaticModelSession(models: ["qwen2.5:7b-instruct", "llama3.2"])
                ),
                RuntimeBooleanConfiguration(
                    name: "Use Cloud",
                    currentValue: true,
                    defaultValue: false,
                    runtimeConfigProvider: provider
                )
            ]
        )

        try await manager.resetToDefaults()

        let inMemory = await provider.currentRuntimeConfig()
        XCTAssertEqual(inMemory.model, "qwen2.5:7b-instruct")
        XCTAssertFalse(inMemory.useCloud)
    }

    private func makeTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeSession() -> URLSession {
        URLProtocol.registerClass(RuntimeConfigurationURLProtocolStub.self)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RuntimeConfigurationURLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func makeStaticModelSession(models: [String]) -> URLSession {
        URLProtocol.registerClass(RuntimeConfigurationURLProtocolStub.self)
        RuntimeConfigurationURLProtocolStub.handler = { request in
            let modelsJSON = models.map { #"{"name":"\#($0)"}"# }.joined(separator: ",")
            let payload = #"{"models":[\#(modelsJSON)]}"#
            let data = payload.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RuntimeConfigurationURLProtocolStub.self]
        return URLSession(configuration: config)
    }
}

private final class RuntimeConfigurationURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
