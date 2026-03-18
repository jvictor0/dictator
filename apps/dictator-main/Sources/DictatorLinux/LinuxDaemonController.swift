import DictatorAppShared
import Foundation
import NIO

enum DaemonCommand: String, Codable {
    case daemon
    case toggle
    case start
    case stop
    case cancel
    case status
    case health
}

struct DaemonRequest: Codable {
    let command: DaemonCommand
}

struct DaemonResponse: Codable {
    let ok: Bool
    let state: String
    let message: String
    let server: String?
}

actor LinuxDaemonController {
    private let lifecycle: DictationLifecycleController
    private let socketPath: String
    private let statusSink: any StatusSink
    private let serverBindDescription: String?
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?

    init(
        lifecycle: DictationLifecycleController,
        socketPath: String,
        statusSink: any StatusSink,
        serverBindDescription: String?
    ) {
        self.lifecycle = lifecycle
        self.socketPath = socketPath
        self.statusSink = statusSink
        self.serverBindDescription = serverBindDescription
    }

    func start() async throws {
        try? FileManager.default.removeItem(atPath: socketPath)

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 16)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(DaemonSocketHandler(controller: self))
            }

        channel = try await bootstrap.bind(unixDomainSocketPath: socketPath).get()
        statusSink.publish("Daemon listening: \(socketPath)")
    }

    func stop() async {
        if let channel {
            try? await channel.close().get()
            self.channel = nil
        }

        try? await group.shutdownGracefully()
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    func handle(command: DaemonCommand) async -> DaemonResponse {
        switch command {
        case .daemon:
            return await makeResponse(ok: true, message: "Daemon")
        case .toggle:
            let ok = await lifecycle.toggleRecording()
            return await makeResponse(ok: ok, message: ok ? "Toggled" : "Toggle rejected")
        case .start:
            let ok = await lifecycle.startRecording()
            return await makeResponse(ok: ok, message: ok ? "Recording started" : "Start rejected")
        case .stop:
            let ok = await lifecycle.stopRecordingAndProcess()
            return await makeResponse(ok: ok, message: ok ? "Recording stopped" : "Stop rejected")
        case .cancel:
            let ok = await lifecycle.cancelRecording()
            return await makeResponse(ok: ok, message: ok ? "Recording cancelled" : "Cancel rejected")
        case .status:
            return await makeResponse(ok: true, message: "Status")
        case .health:
            return await makeResponse(ok: true, message: "OK")
        }
    }

    private func makeResponse(ok: Bool, message: String) async -> DaemonResponse {
        let state = await lifecycle.currentState().rawValue
        return DaemonResponse(ok: ok, state: state, message: message, server: serverBindDescription)
    }
}

private final class DaemonSocketHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let controller: LinuxDaemonController
    private var readBuffer = ""

    init(controller: LinuxDaemonController) {
        self.controller = controller
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var part = unwrapInboundIn(data)
        let fragment = part.readString(length: part.readableBytes) ?? ""
        readBuffer += fragment

        while let newlineIndex = readBuffer.firstIndex(of: "\n") {
            let line = String(readBuffer[..<newlineIndex])
            readBuffer.removeSubrange(...newlineIndex)
            handle(line: line, context: context)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }

    private func handle(line: String, context: ChannelHandlerContext) {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let responseTask = Task {
            let request = try JSONDecoder().decode(DaemonRequest.self, from: Data(line.utf8))
            return await controller.handle(command: request.command)
        }

        Task {
            let response: DaemonResponse
            do {
                response = try await responseTask.value
            } catch {
                response = DaemonResponse(ok: false, state: "unknown", message: "Invalid request: \(error)", server: nil)
            }

            let data = (try? JSONEncoder().encode(response)) ?? Data(#"{"ok":false,"state":"unknown","message":"encode_failed","server":null}"#.utf8)
            context.eventLoop.execute {
                var buffer = context.channel.allocator.buffer(capacity: data.count + 1)
                buffer.writeBytes(data)
                buffer.writeString("\n")
                context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
            }
        }
    }
}

enum LinuxDaemonClient {
    static func send(command: DaemonCommand, socketPath: String) async throws -> DaemonResponse {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try? group.syncShutdownGracefully()
        }

        let responsePromise = group.next().makePromise(of: DaemonResponse.self)

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandler(DaemonClientHandler(responsePromise: responsePromise))
            }

        let channel = try await bootstrap.connect(unixDomainSocketPath: socketPath).get()

        let request = try JSONEncoder().encode(DaemonRequest(command: command))
        var buffer = channel.allocator.buffer(capacity: request.count + 1)
        buffer.writeBytes(request)
        buffer.writeString("\n")
        try await channel.writeAndFlush(buffer).get()

        let response = try await responsePromise.futureResult.get()
        try await channel.close().get()
        return response
    }
}

private final class DaemonClientHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let responsePromise: EventLoopPromise<DaemonResponse>
    private var readBuffer = ""

    init(responsePromise: EventLoopPromise<DaemonResponse>) {
        self.responsePromise = responsePromise
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var part = unwrapInboundIn(data)
        let fragment = part.readString(length: part.readableBytes) ?? ""
        readBuffer += fragment

        guard let newlineIndex = readBuffer.firstIndex(of: "\n") else {
            return
        }

        let line = String(readBuffer[..<newlineIndex])
        do {
            let payload = try JSONDecoder().decode(DaemonResponse.self, from: Data(line.utf8))
            responsePromise.succeed(payload)
        } catch {
            responsePromise.fail(error)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        responsePromise.fail(error)
        context.close(promise: nil)
    }
}
