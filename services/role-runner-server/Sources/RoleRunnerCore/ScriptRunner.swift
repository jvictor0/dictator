import Foundation

public struct ScriptInvocationResult {
    public let terminationStatus: Int32
    public let stdout: Data
    public let stderr: Data

    public init(terminationStatus: Int32, stdout: Data, stderr: Data) {
        self.terminationStatus = terminationStatus
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ScriptExecuting {
    func run(scriptPath: String, repoRoot: String, request: RunRoleRequest, timeoutSeconds: TimeInterval) throws -> ScriptInvocationResult
}

public enum ScriptExecutionError: Error {
    case launchFailed(String)
    case timedOut
}

public struct ProcessScriptExecutor: ScriptExecuting {
    public init() {}

    public func run(scriptPath: String, repoRoot: String, request: RunRoleRequest, timeoutSeconds: TimeInterval) throws -> ScriptInvocationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = [
            "--work-item", request.workItemID,
            "--slice", request.sliceID,
            "--role", request.role.rawValue,
            "--repo-root", repoRoot
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ScriptExecutionError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                throw ScriptExecutionError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ScriptInvocationResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }
}
