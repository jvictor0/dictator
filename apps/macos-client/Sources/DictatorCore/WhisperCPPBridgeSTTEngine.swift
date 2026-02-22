import Foundation

public struct WhisperCPPBridgeSTTEngine: STTEngine {
    public struct Configuration: Sendable {
        public let binaryPath: String
        public let modelPath: String
        public let language: String

        public init(binaryPath: String, modelPath: String, language: String = "auto") {
            self.binaryPath = binaryPath
            self.modelPath = modelPath
            self.language = language
        }

        public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Configuration {
            let binary = env["DICTATOR_WHISPER_CPP_BIN"] ?? "whisper-cli"
            let model = env["DICTATOR_WHISPER_MODEL"] ?? "models/ggml-base.en.bin"
            let language = env["DICTATOR_WHISPER_LANGUAGE"] ?? "auto"
            return Configuration(binaryPath: binary, modelPath: model, language: language)
        }
    }

    public struct RunnerResult: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    public typealias Runner = @Sendable (_ executable: String, _ arguments: [String]) async throws -> RunnerResult

    private let configuration: Configuration
    private let runner: Runner

    public init(
        configuration: Configuration = .fromEnvironment(),
        runner: Runner? = nil
    ) {
        self.configuration = configuration
        self.runner = runner ?? { executable, arguments in
            try await Self.defaultRunner(executable: executable, arguments: arguments)
        }
    }

    public func transcribe(_ request: TranscribeRequest) async throws -> TranscribeResponse {
        guard let audioData = Data(base64Encoded: request.audio_b64) else {
            throw DictatorError.sttFailed("invalid base64 audio payload")
        }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("dictator-whisper-\(UUID().uuidString)")
        let audioURL = tempDir.appendingPathComponent("input.wav")
        let outputPrefix = tempDir.appendingPathComponent("output")
        let outputJSON = outputPrefix.appendingPathExtension("json")

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try audioData.write(to: audioURL, options: .atomic)
            defer { try? fileManager.removeItem(at: tempDir) }

            let args = whisperArguments(audioPath: audioURL.path, outputPrefix: outputPrefix.path)
            let result = try await runner(configuration.binaryPath, args)
            guard result.exitCode == 0 else {
                let detail = result.stderr.isEmpty ? result.stdout : result.stderr
                throw DictatorError.sttFailed("whisper.cpp failed: \(String(detail.prefix(180)))")
            }

            guard fileManager.fileExists(atPath: outputJSON.path) else {
                let debug = result.stderr.isEmpty ? result.stdout : result.stderr
                throw DictatorError.sttFailed("whisper.cpp did not produce JSON output: \(String(debug.prefix(180)))")
            }

            let jsonData = try Data(contentsOf: outputJSON)
            return try Self.parseWhisperJSON(jsonData)
        } catch let error as DictatorError {
            throw error
        } catch {
            throw DictatorError.sttFailed(String(describing: error))
        }
    }

    private func whisperArguments(audioPath: String, outputPrefix: String) -> [String] {
        [
            "-m", configuration.modelPath,
            "-f", audioPath,
            "-oj",
            "-of", outputPrefix,
            "-l", configuration.language,
            "-nt"
        ]
    }

    public static func parseWhisperJSON(_ data: Data) throws -> TranscribeResponse {
        let payload = try JSONDecoder().decode(WhisperOutput.self, from: data)

        let segments = payload.transcription.map {
            TranscribeSegment(start_ms: Int($0.offsets.from / 10), end_ms: Int($0.offsets.to / 10), text: $0.text)
        }

        let transcript = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        let confidence: Double
        if segments.isEmpty {
            confidence = 0.0
        } else {
            let probs = payload.transcription.compactMap { $0.avg_logprob.map(exp) }
            confidence = probs.isEmpty ? 0.0 : probs.reduce(0, +) / Double(probs.count)
        }

        let duration = segments.last?.end_ms ?? 0
        return TranscribeResponse(raw_transcript: transcript, segments: segments, confidence: confidence, duration_ms: duration)
    }

    private static func defaultRunner(executable: String, arguments: [String]) async throws -> RunnerResult {
        let process = Process()
        if executable.contains("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            // Resolve bare executable names using PATH.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return RunnerResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }
}

private struct WhisperOutput: Decodable {
    struct Segment: Decodable {
        struct Offsets: Decodable {
            let from: Int
            let to: Int
        }

        let text: String
        let offsets: Offsets
        let avg_logprob: Double?
    }

    let text: String?
    let transcription: [Segment]
}
