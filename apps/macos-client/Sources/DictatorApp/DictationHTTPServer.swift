import DictatorCore
import Foundation
import NIO
import NIOHTTP1

final class DictationHTTPServer {
    private let host: String
    private let port: Int
    private let maxBodyBytes: Int
    private let coreClient: any DictatorCoreClient
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?

    init(
        host: String,
        port: Int,
        maxBodyBytes: Int = 25 * 1024 * 1024,
        coreClient: any DictatorCoreClient
    ) {
        self.host = host
        self.port = port
        self.maxBodyBytes = maxBodyBytes
        self.coreClient = coreClient
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func start() async throws {
        guard channel == nil else {
            return
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [coreClient, maxBodyBytes] channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(
                        DictationHTTPHandler(
                            coreClient: coreClient,
                            maxBodyBytes: maxBodyBytes
                        )
                    )
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        channel = try await bootstrap.bind(host: host, port: port).get()
    }

    func stop() async {
        if let channel {
            do {
                try await channel.close().get()
            } catch {
                TraceLogger.log("dictation server close failed: \(error)")
            }
            self.channel = nil
        }

        do {
            try await group.shutdownGracefully()
        } catch {
            TraceLogger.log("dictation server shutdown failed: \(error)")
        }
    }

    var bindDescription: String {
        "\(host):\(port)"
    }
}

private final class DictationHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private enum RequestError: Error {
        case notFound
        case methodNotAllowed
        case badRequest(String)
        case payloadTooLarge
        case unprocessableEntity(String)
        case internalServerError(String)

        var status: HTTPResponseStatus {
            switch self {
            case .notFound:
                return .notFound
            case .methodNotAllowed:
                return .methodNotAllowed
            case .badRequest:
                return .badRequest
            case .payloadTooLarge:
                return .payloadTooLarge
            case .unprocessableEntity:
                return .unprocessableEntity
            case .internalServerError:
                return .internalServerError
            }
        }

        var message: String {
            switch self {
            case .notFound:
                return "Not found."
            case .methodNotAllowed:
                return "Method not allowed."
            case let .badRequest(message):
                return message
            case .payloadTooLarge:
                return "Audio payload exceeds 25 MB limit."
            case let .unprocessableEntity(message):
                return message
            case let .internalServerError(message):
                return message
            }
        }
    }

    private struct DictateAudioResponse: Codable {
        let raw_transcript: String
        let revised_text: String
        let edit_summary: String
        let uncertainty_flags: [String]
        let transcribe_ms: Int
        let refine_ms: Int
    }

    private struct ErrorResponse: Codable {
        let error: String
    }

    private struct PendingRequest {
        let head: HTTPRequestHead
        var body = ByteBuffer()
        var responseSent = false
    }

    private let coreClient: any DictatorCoreClient
    private let maxBodyBytes: Int
    private let encoder = JSONEncoder()
    private var pendingRequest: PendingRequest?
    private var activeTask: Task<Void, Never>?

    init(coreClient: any DictatorCoreClient, maxBodyBytes: Int) {
        self.coreClient = coreClient
        self.maxBodyBytes = maxBodyBytes
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case let .head(head):
            pendingRequest = PendingRequest(head: head)
        case var .body(buffer):
            guard var pending = pendingRequest, !pending.responseSent else {
                return
            }
            pending.body.writeBuffer(&buffer)
            if pending.body.readableBytes > maxBodyBytes {
                pending.responseSent = true
                pendingRequest = pending
                writeErrorResponse(.payloadTooLarge, context: context)
                return
            }
            pendingRequest = pending
        case .end:
            guard let pending = pendingRequest, !pending.responseSent else {
                pendingRequest = nil
                return
            }
            pendingRequest = nil
            process(pending: pending, context: context)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        activeTask?.cancel()
        activeTask = nil
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        TraceLogger.log("dictation server channel error: \(error)")
        context.close(promise: nil)
    }

    private func process(pending: PendingRequest, context: ChannelHandlerContext) {
        do {
            guard pending.head.uri == "/v1/dictate-audio" else {
                throw RequestError.notFound
            }
            guard pending.head.method == .POST else {
                throw RequestError.methodNotAllowed
            }

            let contentType = pending.head.headers.first(name: "Content-Type")?.lowercased() ?? ""
            guard contentType.hasPrefix("audio/wav") || contentType.hasPrefix("audio/x-wav") else {
                throw RequestError.badRequest("Content-Type must be audio/wav.")
            }

            guard let sampleRateHeader = pending.head.headers.first(name: "X-Sample-Rate"),
                  let sampleRate = Int(sampleRateHeader), sampleRate > 0 else {
                throw RequestError.badRequest("X-Sample-Rate must be a positive integer.")
            }
            guard let locale = pending.head.headers.first(name: "X-Locale"),
                  !locale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RequestError.badRequest("X-Locale is required.")
            }
            guard let sessionID = pending.head.headers.first(name: "X-Session-Id"),
                  !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RequestError.badRequest("X-Session-Id is required.")
            }

            var body = pending.body
            let wavBytes = body.readBytes(length: body.readableBytes) ?? []
            let wavData = Data(wavBytes)
            guard Self.looksLikeWAV(wavData) else {
                throw RequestError.unprocessableEntity("Payload must be a valid WAV stream.")
            }

            let optionalContext = try parseStringMapHeader(
                pending.head.headers.first(name: "X-Context-Json"),
                headerName: "X-Context-Json"
            )
            let stylePrefs = try parseStringMapHeader(
                pending.head.headers.first(name: "X-Style-Prefs-Json"),
                headerName: "X-Style-Prefs-Json"
            )

            let request = DictateRequest(
                audio_b64: wavData.base64EncodedString(),
                sample_rate: sampleRate,
                locale: locale,
                session_id: sessionID,
                optional_context: optionalContext,
                style_prefs: stylePrefs
            )

            activeTask = Task { [weak self, weak context] in
                guard let self, let context else { return }
                do {
                    let result = try await self.coreClient.dictate(request)
                    if Task.isCancelled {
                        return
                    }
                    let response = DictateAudioResponse(
                        raw_transcript: result.response.raw_transcript,
                        revised_text: result.response.revised_text,
                        edit_summary: result.response.edit_summary,
                        uncertainty_flags: result.response.uncertainty_flags,
                        transcribe_ms: result.transcribeMs,
                        refine_ms: result.refineMs
                    )
                    context.eventLoop.execute {
                        self.writeJSONResponse(response, status: .ok, context: context)
                    }
                } catch {
                    context.eventLoop.execute {
                        self.writeErrorResponse(
                            .internalServerError("Dictation failed: \(error.localizedDescription)"),
                            context: context
                        )
                    }
                }
            }
        } catch let requestError as RequestError {
            writeErrorResponse(requestError, context: context)
        } catch {
            writeErrorResponse(.badRequest("Invalid request: \(error.localizedDescription)"), context: context)
        }
    }

    private func parseStringMapHeader(_ value: String?, headerName: String) throws -> [String: String]? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let data = Data(trimmed.utf8)
        let decoded = try JSONSerialization.jsonObject(with: data)
        guard let object = decoded as? [String: Any] else {
            throw RequestError.badRequest("\(headerName) must be a JSON object.")
        }

        var mapped: [String: String] = [:]
        for (key, raw) in object {
            mapped[key] = String(describing: raw)
        }
        return mapped
    }

    private func writeErrorResponse(_ error: RequestError, context: ChannelHandlerContext) {
        writeJSONResponse(ErrorResponse(error: error.message), status: error.status, context: context)
    }

    private func writeJSONResponse<T: Encodable>(_ payload: T, status: HTTPResponseStatus, context: ChannelHandlerContext) {
        do {
            let data = try encoder.encode(payload)
            var buffer = context.channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(data.count)")
            headers.add(name: "Connection", value: "close")

            let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                context.close(promise: nil)
            }
        } catch {
            let fallback = """
            {"error":"Failed to encode response."}
            """
            var buffer = context.channel.allocator.buffer(capacity: fallback.utf8.count)
            buffer.writeString(fallback)
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(fallback.utf8.count)")
            let head = HTTPResponseHead(version: .http1_1, status: .internalServerError, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                context.close(promise: nil)
            }
        }
    }

    private static func looksLikeWAV(_ data: Data) -> Bool {
        guard data.count >= 44 else {
            return false
        }
        return data.starts(with: [0x52, 0x49, 0x46, 0x46]) // RIFF
            && data[8...11].elementsEqual([0x57, 0x41, 0x56, 0x45]) // WAVE
    }
}
