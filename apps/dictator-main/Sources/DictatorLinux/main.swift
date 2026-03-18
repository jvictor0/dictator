import DictatorAppShared
import DictatorCore
import Dispatch
import Foundation

enum LinuxMainError: Error, CustomStringConvertible {
    case invalidUsage

    var description: String {
        "Usage: DictatorLinux <daemon|toggle|start|stop|cancel|status|health> [--socket path]"
    }
}

enum CLICommand: String {
    case daemon
    case toggle
    case start
    case stop
    case cancel
    case status
    case health

    var daemonCommand: DaemonCommand {
        switch self {
        case .daemon:
            return .daemon
        case .toggle:
            return .toggle
        case .start:
            return .start
        case .stop:
            return .stop
        case .cancel:
            return .cancel
        case .status:
            return .status
        case .health:
            return .health
        }
    }
}

private func parseCommandLine(_ args: [String]) throws -> (CLICommand, String) {
    guard args.count >= 2, let command = CLICommand(rawValue: args[1].lowercased()) else {
        throw LinuxMainError.invalidUsage
    }

    var socketPath = "/tmp/dictator-linux.sock"
    var index = 2
    while index < args.count {
        let arg = args[index]
        if arg == "--socket", index + 1 < args.count {
            socketPath = args[index + 1]
            index += 2
            continue
        }
        throw LinuxMainError.invalidUsage
    }

    return (command, socketPath)
}

private func buildDependencies() async throws -> (
    lifecycle: DictationLifecycleController,
    httpServer: DictationHTTPServer?,
    statusSink: ConsoleStatusSink
) {
    let statusSink = ConsoleStatusSink()
    let runtimeConfigStore = RuntimeConfigStore(fileURL: RuntimeConfigStore.defaultFileURL())
    let safeRuntimeConfigStore = RuntimeConfigStore(fileURL: RuntimeConfigStore.defaultSafeFileURL())
    let runtimeProvider = RuntimeConfigProvider(store: runtimeConfigStore, defaultStore: safeRuntimeConfigStore)

    let startupConfig = (try? runtimeConfigStore.load()) ?? (try? safeRuntimeConfigStore.load()) ?? RuntimeConfigFile.bootstrap()

    let inMemorySecretStore = InMemorySecretStore(openAIKey: try SecretsStore().getOpenAIKey())

    let sttEngine = WhisperCPPBridgeSTTEngine(
        configuration: .init(
            modelPath: startupConfig.resolvedSTTModelPath(),
            language: startupConfig.sttLanguage
        )
    )

    let refinementEngine = RuntimeConfigRefinementEngine(
        runtimeConfigProvider: runtimeProvider,
        secretStore: inMemorySecretStore,
        canUseOpenAI: {
            (try? inMemorySecretStore.getOpenAIKey()) != nil
        }
    )

    let coreClient = PipelineOrchestrator(sttEngine: sttEngine, refinementEngine: refinementEngine)

    let lifecycle = DictationLifecycleController(
        coreClient: coreClient,
        recordingBackend: PipeWireAudioRecorder(),
        insertionBackend: WaylandClipboardInserter(),
        statusSink: statusSink
    )

    let httpServer: DictationHTTPServer?
    if startupConfig.dictatorServerEnabled {
        httpServer = DictationHTTPServer(
            host: startupConfig.dictatorServerHost,
            port: startupConfig.dictatorServerPort,
            coreClient: coreClient,
            log: { statusSink.publish($0) }
        )
    } else {
        httpServer = nil
    }

    return (lifecycle, httpServer, statusSink)
}

private func run() async throws {
    let (command, socketPath) = try parseCommandLine(CommandLine.arguments)

    switch command {
    case .daemon:
        let dependencies = try await buildDependencies()
        let daemon = LinuxDaemonController(
            lifecycle: dependencies.lifecycle,
            socketPath: socketPath,
            statusSink: dependencies.statusSink,
            serverBindDescription: dependencies.httpServer?.bindDescription
        )

        try await daemon.start()
        if let httpServer = dependencies.httpServer {
            try await httpServer.start()
        }

        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler {
            Task {
                if let httpServer = dependencies.httpServer {
                    await httpServer.stop()
                }
                await daemon.stop()
                exit(0)
            }
        }
        signalSource.resume()
        dispatchMain()

    case .toggle, .start, .stop, .cancel, .status, .health:
        let response = try await LinuxDaemonClient.send(command: command.daemonCommand, socketPath: socketPath)
        let data = try JSONEncoder().encode(response)
        print(String(decoding: data, as: UTF8.self))
    }
}

let semaphore = DispatchSemaphore(value: 0)
Task {
    do {
        try await run()
    } catch {
        fputs("dictator-linux error: \(error)\n", stderr)
        exit(1)
    }
    semaphore.signal()
}
semaphore.wait()
