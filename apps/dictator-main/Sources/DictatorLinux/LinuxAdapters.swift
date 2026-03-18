import DictatorAppShared
import Foundation

struct CommandExecutionResult: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

protocol CommandRunning: Sendable {
    func run(_ executable: String, arguments: [String], stdin: Data?) throws -> CommandExecutionResult
    func isAvailable(_ executable: String) -> Bool
}

struct ProcessCommandRunner: CommandRunning {
    func run(_ executable: String, arguments: [String], stdin: Data? = nil) throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let stdin {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            try process.run()
            inputPipe.fileHandleForWriting.write(stdin)
            try? inputPipe.fileHandleForWriting.close()
        } else {
            try process.run()
        }

        process.waitUntilExit()

        return CommandExecutionResult(
            status: process.terminationStatus,
            stdout: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            stderr: errorPipe.fileHandleForReading.readDataToEndOfFile()
        )
    }

    func isAvailable(_ executable: String) -> Bool {
        do {
            let result = try run("which", arguments: [executable], stdin: nil)
            return result.status == 0
        } catch {
            return false
        }
    }
}

enum LinuxAdapterError: Error, CustomStringConvertible {
    case toolMissing(String)
    case commandFailed(tool: String, stderr: String)
    case alreadyRecording
    case notRecording
    case readFailed(String)

    var description: String {
        switch self {
        case let .toolMissing(tool):
            return "Required tool missing: \(tool)"
        case let .commandFailed(tool, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Command failed: \(tool)" : "Command failed: \(tool): \(trimmed)"
        case .alreadyRecording:
            return "Recording is already active"
        case .notRecording:
            return "Recording is not active"
        case let .readFailed(message):
            return "Failed to read recording: \(message)"
        }
    }
}

final class PipeWireAudioRecorder: RecordingBackend, @unchecked Sendable {
    private let runner: any CommandRunning
    private let sampleRate: Int
    private let lock = NSLock()
    private var process: Process?
    private var outputURL: URL?

    init(runner: any CommandRunning = ProcessCommandRunner(), sampleRate: Int = 16_000) {
        self.runner = runner
        self.sampleRate = sampleRate
    }

    func startCapture() async throws {
        guard runner.isAvailable("pw-record") else {
            throw LinuxAdapterError.toolMissing("pw-record")
        }

        try lock.withLock {
            guard process == nil else {
                throw LinuxAdapterError.alreadyRecording
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("dictator-linux-\(UUID().uuidString)")
                .appendingPathExtension("wav")

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [
                "pw-record",
                "--rate", String(sampleRate),
                "--channels", "1",
                "--format", "s16",
                outputURL.path
            ]
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            try proc.run()

            process = proc
            self.outputURL = outputURL
        }
    }

    func stopCapture() async throws -> CapturedAudioChunk {
        let url: URL = try lock.withLock {
            guard let process, let outputURL else {
                throw LinuxAdapterError.notRecording
            }
            process.terminate()
            process.waitUntilExit()
            self.process = nil
            self.outputURL = nil
            return outputURL
        }

        do {
            let data = try Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            return CapturedAudioChunk(data: data, sampleRate: sampleRate)
        } catch {
            throw LinuxAdapterError.readFailed(String(describing: error))
        }
    }

    func cancelCapture() async {
        let url = lock.withLock { () -> URL? in
            guard let process, let outputURL else {
                return nil
            }
            process.terminate()
            process.waitUntilExit()
            self.process = nil
            self.outputURL = nil
            return outputURL
        }

        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

final class WaylandClipboardInserter: TextInsertionBackend, @unchecked Sendable {
    private let runner: any CommandRunning

    init(runner: any CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    func insertText(_ text: String) throws {
        guard runner.isAvailable("wl-copy") else {
            throw LinuxAdapterError.toolMissing("wl-copy")
        }
        guard runner.isAvailable("wl-paste") else {
            throw LinuxAdapterError.toolMissing("wl-paste")
        }
        guard runner.isAvailable("wtype") else {
            throw LinuxAdapterError.toolMissing("wtype")
        }

        let previous = try runner.run("wl-paste", arguments: ["--no-newline"], stdin: nil)
        let previousText = previous.status == 0 ? previous.stdout : Data()

        let copyResult = try runner.run("wl-copy", arguments: [], stdin: Data(text.utf8))
        guard copyResult.status == 0 else {
            throw LinuxAdapterError.commandFailed(tool: "wl-copy", stderr: String(data: copyResult.stderr, encoding: .utf8) ?? "")
        }

        defer {
            if previousText.isEmpty {
                _ = try? runner.run("wl-copy", arguments: ["--clear"], stdin: nil)
            } else {
                _ = try? runner.run("wl-copy", arguments: [], stdin: previousText)
            }
        }

        let pasteResult = try runner.run("wtype", arguments: ["-M", "ctrl", "v", "-m", "ctrl"], stdin: nil)
        guard pasteResult.status == 0 else {
            throw LinuxAdapterError.commandFailed(tool: "wtype", stderr: String(data: pasteResult.stderr, encoding: .utf8) ?? "")
        }
    }
}

struct ConsoleStatusSink: StatusSink {
    func publish(_ message: String) {
        fputs("[dictator-linux] \(message)\n", stderr)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
