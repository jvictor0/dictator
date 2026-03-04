import AVFoundation
import SwiftUI
import UIKit

struct HostAppRootView: View {
    private struct TracedRequestError: Error {
        let base: Error
        let traces: [String]
    }

    private struct UploadResult {
        let response: DictateAudioResponse
        let traces: [String]
    }

    private enum DictationState {
        case idle
        case recording
        case waitingForServer
        case error(String)
    }

    private struct DictateAudioResponse: Decodable {
        let raw_transcript: String
        let revised_text: String
        let edit_summary: String
        let uncertainty_flags: [String]
        let transcribe_ms: Int
        let refine_ms: Int
    }

    @State private var state: DictationState = .idle
    @State private var latestTranscript: String?
    @State private var latestTranscriptUpdatedAt: Date?
    @State private var diagnostics: [String] = []
    @State private var serverURLDraft: String = ""
    @State private var isRunningProbe = false
    @Environment(\.scenePhase) private var scenePhase

    private let recorder = AudioSnippetRecorder()
    private let sessionID = UUID().uuidString

    private var configuredServerURL: String {
        SharedConfig.resolvedServerURLString(bundle: .main)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dictation") {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(stateIsError ? Color.red : Color.secondary)

                    Button(buttonTitle, action: handleDictationTap)
                        .buttonStyle(.borderedProminent)
                        .disabled(isWaitingForServer)

                    if let latestTranscript {
                        Text("Latest transcript:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(latestTranscript)
                            .font(.body)

                        if let latestTranscriptUpdatedAt {
                            Text("Saved: \(latestTranscriptUpdatedAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No transcript has been saved yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Keyboard Setup") {
                    Text("1. Enable Dictator keyboard in Settings > General > Keyboard.")
                    Text("2. Switch to the Dictator keyboard in any text field.")
                    Text("3. Tap Insert Latest Transcript in the keyboard to paste shared dictation text.")
                    Text("4. Tap Open Dictator App in the keyboard to launch this host app.")
                }

                Section("Status") {
                    Text("Server URL: \(configuredServerURL)")
                    TextField("http://host:8787", text: $serverURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save Server URL") {
                        SharedConfig.saveServerURLString(serverURLDraft)
                        addTrace("Server URL override saved: \(SharedConfig.resolvedServerURLString(bundle: .main))")
                    }
                    Text("Transcripts are saved to the app group for the keyboard extension.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnostics") {
                    Button("Refresh Trace") {
                        refreshDiagnosticsFromDisk()
                    }

                    Button("Run Connectivity Probe") {
                        Task {
                            await runConnectivityProbe()
                        }
                    }
                    .disabled(isRunningProbe)

                    Button("Copy Trace") {
                        copyTraceToClipboard()
                    }

                    Button("Clear Trace") {
                        diagnostics.removeAll()
                        SharedConfig.clearDiagnosticsLog()
                    }

                    if let logURL = SharedConfig.diagnosticsLogURL() {
                        Text("Log file: \(logURL.path)")
                            .font(.caption2)
                            .textSelection(.enabled)
                    }

                    if diagnostics.isEmpty {
                        Text("No trace events yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(diagnostics.suffix(20).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Dictator Keyboard")
        }
        .task {
            refreshLatestTranscript()
            serverURLDraft = configuredServerURL
            refreshDiagnosticsFromDisk()
        }
        .onOpenURL { url in
            refreshDiagnosticsFromDisk()
            addTrace("App opened via URL: \(url.absoluteString)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshDiagnosticsFromDisk()
            }
        }
    }

    private var stateIsError: Bool {
        if case .error = state {
            return true
        }
        return false
    }

    private var isWaitingForServer: Bool {
        if case .waitingForServer = state {
            return true
        }
        return false
    }

    private var buttonTitle: String {
        switch state {
        case .idle, .error:
            return "Start Recording"
        case .recording:
            return "Stop Recording"
        case .waitingForServer:
            return "Processing..."
        }
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .waitingForServer:
            return "Waiting for Dictator server..."
        case let .error(message):
            return message
        }
    }

    private func handleDictationTap() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            Task {
                await finishRecordingAndSend()
            }
        case .waitingForServer:
            return
        }
    }

    private func refreshLatestTranscript() {
        latestTranscript = SharedConfig.loadLatestTranscript()
        latestTranscriptUpdatedAt = SharedConfig.loadLatestTranscriptUpdatedAt()
    }

    private func startRecording() {
        do {
            try recorder.start()
            addTrace("Mic recording started.")
            state = .recording
        } catch {
            state = .error(microphoneErrorMessage(error))
            addTrace("Mic start error: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func finishRecordingAndSend() async {
        state = .waitingForServer
        addTrace("Stop requested. Finalizing audio buffer...")
        let wavData: Data
        do {
            wavData = try recorder.stopAndBuildWAV()
            addTrace("Audio captured: \(wavData.count) bytes WAV.")
        } catch {
            state = .error("Mic stop failed: \(error.localizedDescription)")
            addTrace("Mic stop error: \(error.localizedDescription)")
            return
        }

        let baseURL = loadBaseURL()
        addTrace("Resolved server URL: \(baseURL.absoluteString)")

        do {
            let result = try await uploadSnippet(wavData: wavData, baseURL: baseURL)
            result.traces.forEach(addTrace)
            let revisedText = result.response.revised_text.trimmingCharacters(in: .whitespacesAndNewlines)
            if revisedText.isEmpty {
                state = .error("Server returned empty revised text.")
                addTrace("Server returned empty revised_text.")
                return
            }

            SharedConfig.saveLatestTranscript(revisedText)
            refreshLatestTranscript()
            addTrace("Transcript saved to app group (\(revisedText.count) chars).")
            state = .idle
        } catch {
            if let traced = error as? TracedRequestError {
                traced.traces.forEach(addTrace)
                state = .error(requestErrorMessage(traced.base))
            } else {
                addTrace("Request failed without trace wrapper: \(error.localizedDescription)")
                state = .error(requestErrorMessage(error))
            }
        }
    }

    private func uploadSnippet(wavData: Data, baseURL: URL) async throws -> UploadResult {
        var traces: [String] = []
        let requestID = String(UUID().uuidString.prefix(8))
        var endpoint = baseURL
        endpoint.appendPathComponent("v1")
        endpoint.appendPathComponent("dictate-audio")
        traces.append("[\(requestID)] POST \(endpoint.absoluteString)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.setValue("16000", forHTTPHeaderField: "X-Sample-Rate")
        request.setValue("en-US", forHTTPHeaderField: "X-Locale")
        request.setValue(sessionID, forHTTPHeaderField: "X-Session-Id")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-Id")
        request.httpBody = wavData
        traces.append("[\(requestID)] timeout=\(Int(request.timeoutInterval))s payload=\(wavData.count) bytes")

        var data: Data?
        var response: URLResponse?
        var lastError: Error?
        for attempt in 1 ... 2 {
            let delegate = UploadTaskDelegate()
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let startedAt = Date()
            do {
                let result = try await session.data(for: request)
                data = result.0
                response = result.1
                let elapsed = Date().timeIntervalSince(startedAt)
                traces.append("[\(requestID)] attempt \(attempt) completed in \(String(format: "%.3f", elapsed))s, responseBytes=\(result.0.count)")
                if let metricsSummary = delegate.metricsSummary {
                    traces.append("[\(requestID)] attempt \(attempt) metrics: \(metricsSummary)")
                }
                lastError = nil
                break
            } catch {
                lastError = error
                traces.append("[\(requestID)] attempt \(attempt) URLSession error: \(traceString(for: error))")
                if let metricsSummary = delegate.metricsSummary {
                    traces.append("[\(requestID)] attempt \(attempt) metrics: \(metricsSummary)")
                }
                guard attempt == 1, shouldRetry(error: error) else {
                    throw TracedRequestError(base: error, traces: traces)
                }
                traces.append("[\(requestID)] retrying once after transient network error...")
            }
        }
        guard let data, let response else {
            throw TracedRequestError(base: lastError ?? URLError(.unknown), traces: traces)
        }

        guard let http = response as? HTTPURLResponse else {
            let err = NSError(domain: "DictatorKeyboard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
            traces.append("[\(requestID)] invalid response object: \(type(of: response))")
            throw TracedRequestError(base: err, traces: traces)
        }
        traces.append("[\(requestID)] status=\(http.statusCode)")
        guard (200 ... 299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            traces.append("[\(requestID)] non-2xx body: \(text.prefix(200))")
            let err = NSError(domain: "DictatorKeyboard", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
            throw TracedRequestError(base: err, traces: traces)
        }
        do {
            let decoded = try JSONDecoder().decode(DictateAudioResponse.self, from: data)
            return UploadResult(response: decoded, traces: traces)
        } catch {
            traces.append("[\(requestID)] decode error: \(error.localizedDescription)")
            throw TracedRequestError(base: error, traces: traces)
        }
    }

    private func loadBaseURL() -> URL {
        let resolved = SharedConfig.resolvedServerURLString(bundle: .main)
        return URL(string: resolved) ?? URL(string: SharedConfig.fallbackServerURL)!
    }

    private func microphoneErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        return "Mic start failed: \(nsError.localizedDescription)"
    }

    private func requestErrorMessage(_ error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "Request failed: \(error.localizedDescription)"
        }

        switch urlError.code {
        case .notConnectedToInternet:
            return "Cannot reach Dictator server. iOS reports Local Network access is blocked or offline. Enable Local Network for this app in Settings, then retry."
        case .cannotConnectToHost:
            return "Cannot connect to Dictator server at \(configuredServerURL). Check host/port and confirm the server is listening on your LAN interface."
        case .timedOut:
            return "Dictator server request timed out. Confirm the server is running and reachable at \(configuredServerURL)."
        default:
            return "Request failed: \(urlError.localizedDescription)"
        }
    }

    @MainActor
    private func runConnectivityProbe() async {
        guard !isRunningProbe else {
            addTrace("Connectivity probe skipped: already running.")
            return
        }
        isRunningProbe = true
        defer { isRunningProbe = false }

        addTrace("Connectivity probe started for \(configuredServerURL)")
        guard let baseURL = URL(string: configuredServerURL) else {
            addTrace("Connectivity probe failed: invalid URL.")
            return
        }

        let probePaths = ["health"]
        for path in probePaths {
            var url = baseURL
            if !path.isEmpty {
                url.appendPathComponent(path)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 8
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    addTrace("Probe \(url.absoluteString) -> HTTP \(http.statusCode)")
                } else {
                    addTrace("Probe \(url.absoluteString) -> non-HTTP response")
                }
            } catch {
                addTrace("Probe \(url.absoluteString) failed: \(traceString(for: error))")
            }
        }
    }

    @MainActor
    private func addTrace(_ line: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let full = "[\(timestamp)] \(line)"
        diagnostics.append(full)
        SharedConfig.appendDiagnosticsLine(full)
    }

    private func refreshDiagnosticsFromDisk() {
        guard let persisted = SharedConfig.readDiagnosticsLog() else {
            return
        }
        let lines = persisted
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        diagnostics = Array(lines.suffix(100))
    }

    private func traceString(for error: Error) -> String {
        let nsError = error as NSError
        var parts = ["\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=\(underlying.domain) \(underlying.code): \(underlying.localizedDescription)")
        }
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            parts.append("url=\(failingURL.absoluteString)")
        }
        if let nwPath = nsError.userInfo["_NSURLErrorNWPathKey"] {
            parts.append("nwPath=\(nwPath)")
        }
        return parts.joined(separator: " | ")
    }

    private func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }

    private func copyTraceToClipboard() {
        if let persisted = SharedConfig.readDiagnosticsLog(), !persisted.isEmpty {
            UIPasteboard.general.string = persisted
            addTrace("Copied persisted diagnostics log to clipboard.")
            return
        }

        let fallback = diagnostics.joined(separator: "\n")
        UIPasteboard.general.string = fallback
        addTrace("Copied in-memory diagnostics trace to clipboard.")
    }
}

private final class UploadTaskDelegate: NSObject, URLSessionTaskDelegate {
    private(set) var metricsSummary: String?

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let metric = metrics.transactionMetrics.last else {
            return
        }

        func ms(_ start: Date?, _ end: Date?) -> String {
            guard let start, let end else {
                return "n/a"
            }
            return String(format: "%.1fms", end.timeIntervalSince(start) * 1000)
        }

        metricsSummary = [
            "fetch=\(metric.resourceFetchType.rawValue)",
            "reused=\(metric.isReusedConnection)",
            "protocol=\(metric.networkProtocolName ?? "n/a")",
            "dns=\(ms(metric.domainLookupStartDate, metric.domainLookupEndDate))",
            "connect=\(ms(metric.connectStartDate, metric.connectEndDate))",
            "tls=\(ms(metric.secureConnectionStartDate, metric.secureConnectionEndDate))",
            "request=\(ms(metric.requestStartDate, metric.requestEndDate))",
            "response=\(ms(metric.responseStartDate, metric.responseEndDate))"
        ].joined(separator: ", ")
    }
}

private final class AudioSnippetRecorder {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private let lock = NSLock()
    private var pcmData = Data()
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var isRecording = false

    func start() throws {
        guard !isRecording else {
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: [])

        let inputNode = engine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        guard let destinationFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "DictatorKeyboard", code: 100, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio format"])
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw NSError(domain: "DictatorKeyboard", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio converter"])
        }
        self.converter = converter
        inputFormat = sourceFormat
        lock.lock()
        pcmData.removeAll(keepingCapacity: true)
        lock.unlock()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: sourceFormat) { [weak self] buffer, _ in
            self?.capture(buffer: buffer, converter: converter, destinationFormat: destinationFormat)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopAndBuildWAV() throws -> Data {
        guard isRecording else {
            throw NSError(domain: "DictatorKeyboard", code: 102, userInfo: [NSLocalizedDescriptionKey: "Recorder is not running"])
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRecording = false

        lock.lock()
        let pcm = pcmData
        lock.unlock()
        guard !pcm.isEmpty else {
            throw NSError(domain: "DictatorKeyboard", code: 103, userInfo: [NSLocalizedDescriptionKey: "No audio captured"])
        }
        return Self.makeWAV(pcm16MonoData: pcm, sampleRate: Int(targetSampleRate))
    }

    private func capture(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, destinationFormat: AVAudioFormat) {
        let expectedFrames = AVAudioFrameCount((Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate).rounded(.up))
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: destinationFormat,
            frameCapacity: max(expectedFrames, 1)
        ) else {
            return
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            } else {
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }
        }

        guard conversionError == nil, status == .haveData else {
            return
        }
        guard let channelData = converted.int16ChannelData else {
            return
        }

        let frameLength = Int(converted.frameLength)
        let byteCount = frameLength * MemoryLayout<Int16>.size
        let pointer = UnsafeRawPointer(channelData.pointee)
        lock.lock()
        pcmData.append(pointer.assumingMemoryBound(to: UInt8.self), count: byteCount)
        lock.unlock()
    }

    private static func makeWAV(pcm16MonoData: Data, sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let blockAlign = UInt16(channels * (bitsPerSample / 8))
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let dataSize = UInt32(pcm16MonoData.count)
        let riffSize = UInt32(36) + dataSize

        var data = Data(capacity: Int(riffSize) + 8)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        data.append(contentsOf: riffSize.littleEndianBytes)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes) // PCM
        data.append(contentsOf: channels.littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        data.append(contentsOf: dataSize.littleEndianBytes)
        data.append(pcm16MonoData)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }
}
