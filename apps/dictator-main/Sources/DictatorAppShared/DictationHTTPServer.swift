import DictatorCore
import Foundation
import NIO
import NIOHTTP1

public struct DictationHTTPSuccessRecord: Sendable {
    public let response: DictateResponse
    public let transcribeMs: Int
    public let refineMs: Int
    public let totalPipelineMs: Int
    public let optionalContext: [String: String]?

    public init(
        response: DictateResponse,
        transcribeMs: Int,
        refineMs: Int,
        totalPipelineMs: Int,
        optionalContext: [String: String]?
    ) {
        self.response = response
        self.transcribeMs = transcribeMs
        self.refineMs = refineMs
        self.totalPipelineMs = totalPipelineMs
        self.optionalContext = optionalContext
    }
}

public struct DictationHTTPFailureRecord: Sendable {
    public let errorMessage: String
    public let optionalContext: [String: String]?
    public let audioData: Data
    public let sampleRate: Int
    public let locale: String

    public init(errorMessage: String, optionalContext: [String: String]?, audioData: Data, sampleRate: Int, locale: String) {
        self.errorMessage = errorMessage
        self.optionalContext = optionalContext
        self.audioData = audioData
        self.sampleRate = sampleRate
        self.locale = locale
    }
}

public final class DictationHTTPServer {
    private let host: String
    private let port: Int
    private let maxBodyBytes: Int
    private let coreClient: any DictatorCoreClient
    private let onSuccessRecord: (@Sendable (DictationHTTPSuccessRecord) async -> Void)?
    private let onFailureRecord: (@Sendable (DictationHTTPFailureRecord) async -> Void)?
    private let log: @Sendable (String) -> Void
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?

    public init(
        host: String,
        port: Int,
        maxBodyBytes: Int = 25 * 1024 * 1024,
        coreClient: any DictatorCoreClient,
        onSuccessRecord: (@Sendable (DictationHTTPSuccessRecord) async -> Void)? = nil,
        onFailureRecord: (@Sendable (DictationHTTPFailureRecord) async -> Void)? = nil,
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.host = host
        self.port = port
        self.maxBodyBytes = maxBodyBytes
        self.coreClient = coreClient
        self.onSuccessRecord = onSuccessRecord
        self.onFailureRecord = onFailureRecord
        self.log = log
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    public func start() async throws {
        guard channel == nil else {
            return
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [coreClient, maxBodyBytes, onSuccessRecord, onFailureRecord, log] channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(
                        DictationHTTPHandler(
                            coreClient: coreClient,
                            maxBodyBytes: maxBodyBytes,
                            onSuccessRecord: onSuccessRecord,
                            onFailureRecord: onFailureRecord,
                            log: log
                        )
                    )
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        channel = try await bootstrap.bind(host: host, port: port).get()
        log("dictation server listening on \(bindDescription)")
    }

    public func stop() async {
        if let channel {
            do {
                try await channel.close().get()
            } catch {
                log("dictation server close failed: \(error)")
            }
            self.channel = nil
        }

        do {
            try await group.shutdownGracefully()
        } catch {
            log("dictation server shutdown failed: \(error)")
        }
    }

    public var bindDescription: String {
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
    private let onSuccessRecord: (@Sendable (DictationHTTPSuccessRecord) async -> Void)?
    private let onFailureRecord: (@Sendable (DictationHTTPFailureRecord) async -> Void)?
    private let log: @Sendable (String) -> Void
    private let encoder = JSONEncoder()
    private var pendingRequest: PendingRequest?
    private var activeTask: Task<Void, Never>?

    init(
        coreClient: any DictatorCoreClient,
        maxBodyBytes: Int,
        onSuccessRecord: (@Sendable (DictationHTTPSuccessRecord) async -> Void)?,
        onFailureRecord: (@Sendable (DictationHTTPFailureRecord) async -> Void)?,
        log: @escaping @Sendable (String) -> Void
    ) {
        self.coreClient = coreClient
        self.maxBodyBytes = maxBodyBytes
        self.onSuccessRecord = onSuccessRecord
        self.onFailureRecord = onFailureRecord
        self.log = log
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case let .head(head):
            let remote = context.remoteAddress?.description ?? "unknown"
            let contentLength = head.headers.first(name: "Content-Length") ?? "n/a"
            let transferEncoding = head.headers.first(name: "Transfer-Encoding") ?? "n/a"
            let requestID = head.headers.first(name: "X-Request-Id") ?? "missing"
            log("dictation HTTP request head: id=\(requestID) \(head.method.rawValue) \(head.uri) remote=\(remote) contentLength=\(contentLength) transferEncoding=\(transferEncoding)")
            pendingRequest = PendingRequest(head: head)
        case var .body(buffer):
            guard var pending = pendingRequest, !pending.responseSent else {
                return
            }
            pending.body.writeBuffer(&buffer)
            if pending.body.readableBytes > maxBodyBytes {
                pending.responseSent = true
                pendingRequest = pending
                writeErrorResponse(.payloadTooLarge, context: context, closeAfterResponse: true)
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
        log("dictation server channel inactive")
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log("dictation server channel error: \(error)")
        context.close(promise: nil)
    }

    private func process(pending: PendingRequest, context: ChannelHandlerContext) {
        let requestID = pending.head.headers.first(name: "X-Request-Id") ?? String(UUID().uuidString.prefix(8))
        let requestStart = Date()
        do {
            if pending.head.uri == "/health", pending.head.method == .GET {
                log("[\(requestID)] health check request")
                writeJSONResponse(
                    ["status": "ok"],
                    status: .ok,
                    context: context,
                    closeAfterResponse: !pending.head.isKeepAlive
                )
                return
            }

            guard pending.head.uri == "/v1/dictate-audio" else {
                throw RequestError.notFound
            }
            guard pending.head.method == .POST else {
                throw RequestError.methodNotAllowed
            }

            log("[\(requestID)] /v1/dictate-audio accepted (bytes=\(pending.body.readableBytes))")

            let contentType = pending.head.headers.first(name: "Content-Type")?.lowercased() ?? ""
            guard contentType.hasPrefix("audio/wav") || contentType.hasPrefix("audio/x-wav") else {
                throw RequestError.badRequest("Content-Type must be audio/wav.")
            }

            guard let sampleRateHeader = pending.head.headers.first(name: "X-Sample-Rate"),
                  let sampleRate = Int(sampleRateHeader), sampleRate > 0 else {
                throw RequestError.badRequest("X-Sample-Rate must be a positive integer.")
            }

            let locale = pending.head.headers.first(name: "X-Locale")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedLocale = locale?.isEmpty == false ? locale! : "en-US"

            let sessionIDHeader = pending.head.headers.first(name: "X-Session-Id")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sessionID = sessionIDHeader?.isEmpty == false ? sessionIDHeader! : UUID().uuidString

            let optionalContextHeader = pending.head.headers.first(name: "X-Optional-Context")
            let optionalContext = decodeOptionalContext(optionalContextHeader)

            let audioBytes = pending.body.getBytes(at: pending.body.readerIndex, length: pending.body.readableBytes) ?? []
            let audioData = Data(audioBytes)
            guard !audioData.isEmpty else {
                throw RequestError.badRequest("Request body must contain WAV audio bytes.")
            }

            activeTask?.cancel()
            activeTask = Task {
                do {
                    let dictated = try await coreClient.dictate(
                        DictateRequest(
                            audio_b64: audioData.base64EncodedString(),
                            sample_rate: sampleRate,
                            locale: resolvedLocale,
                            session_id: sessionID,
                            optional_context: optionalContext
                        )
                    )

                    let payload = DictateAudioResponse(
                        raw_transcript: dictated.response.raw_transcript,
                        revised_text: dictated.response.revised_text,
                        edit_summary: dictated.response.edit_summary,
                        uncertainty_flags: dictated.response.uncertainty_flags,
                        transcribe_ms: dictated.transcribeMs,
                        refine_ms: dictated.refineMs
                    )

                    let totalPipelineMs = Int(Date().timeIntervalSince(requestStart) * 1000)
                    if let onSuccessRecord {
                        await onSuccessRecord(
                            DictationHTTPSuccessRecord(
                                response: dictated.response,
                                transcribeMs: dictated.transcribeMs,
                                refineMs: dictated.refineMs,
                                totalPipelineMs: totalPipelineMs,
                                optionalContext: optionalContext
                            )
                        )
                    }

                    context.eventLoop.execute {
                        self.writeJSONResponse(
                            payload,
                            status: .ok,
                            context: context,
                            closeAfterResponse: !pending.head.isKeepAlive
                        )
                    }
                } catch {
                    let message = String(describing: error)
                    if let onFailureRecord {
                        await onFailureRecord(
                            DictationHTTPFailureRecord(
                                errorMessage: message,
                                optionalContext: optionalContext,
                                audioData: audioData,
                                sampleRate: sampleRate,
                                locale: resolvedLocale
                            )
                        )
                    }
                    context.eventLoop.execute {
                        self.writeErrorResponse(.unprocessableEntity(message), context: context, closeAfterResponse: !pending.head.isKeepAlive)
                    }
                }
            }
        } catch let requestError as RequestError {
            writeErrorResponse(requestError, context: context, closeAfterResponse: !pending.head.isKeepAlive)
        } catch {
            writeErrorResponse(.internalServerError(String(describing: error)), context: context, closeAfterResponse: !pending.head.isKeepAlive)
        }
    }

    private func decodeOptionalContext(_ headerValue: String?) -> [String: String]? {
        guard let headerValue,
              let data = Data(base64Encoded: headerValue),
              !data.isEmpty else {
            return nil
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var result: [String: String] = [:]
        for (key, value) in object {
            if let stringValue = value as? String {
                result[key] = stringValue
            }
        }
        return result.isEmpty ? nil : result
    }

    private func writeErrorResponse(_ error: RequestError, context: ChannelHandlerContext, closeAfterResponse: Bool) {
        writeJSONResponse(
            ErrorResponse(error: error.message),
            status: error.status,
            context: context,
            closeAfterResponse: closeAfterResponse
        )
    }

    private func writeJSONResponse<T: Encodable>(
        _ payload: T,
        status: HTTPResponseStatus,
        context: ChannelHandlerContext,
        closeAfterResponse: Bool
    ) {
        do {
            let data = try encoder.encode(payload)
            var buffer = context.channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: String(data.count))
            if !closeAfterResponse {
                headers.add(name: "Connection", value: "keep-alive")
            }

            let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                if closeAfterResponse {
                    context.close(promise: nil)
                }
            }
        } catch {
            let fallback = #"{"error":"failed to encode response"}"#
            var buffer = context.channel.allocator.buffer(capacity: fallback.utf8.count)
            buffer.writeString(fallback)
            let headers = HTTPHeaders([
                ("Content-Type", "application/json"),
                ("Content-Length", String(fallback.utf8.count))
            ])
            let head = HTTPResponseHead(version: .http1_1, status: .internalServerError, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                if closeAfterResponse {
                    context.close(promise: nil)
                }
            }
        }
    }
}
