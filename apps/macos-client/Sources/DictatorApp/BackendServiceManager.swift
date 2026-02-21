import Foundation

final class BackendServiceManager {
    enum BackendError: Error {
        case repoRootNotFound
        case pythonNotFound
        case bootstrapFailed(String)
        case launchFailed
        case healthTimeout
        case exitFailed
    }

    private(set) var baseURL: URL
    private let host: String
    private let port: Int
    private var process: Process?
    private var ownsProcess = false
    private static let installFailureMarker = ".venv/.dictator_install_failed"
    private static let installRetryIntervalSeconds: TimeInterval = 600

    init() {
        let env = ProcessInfo.processInfo.environment
        self.host = env["DICTATOR_BACKEND_HOST"] ?? "127.0.0.1"
        self.port = Int(env["DICTATOR_BACKEND_PORT"] ?? "") ?? 8780
        self.baseURL = URL(string: "http://\(host):\(port)")!
    }

    func start() async -> Result<URL, BackendError> {
        if await isBackendHealthy() {
            TraceLogger.log("backend manager: existing backend detected, requesting graceful exit")
            let requested = await requestExit()
            if !requested {
                TraceLogger.log("backend manager: existing backend did not accept /exit")
                if ownsProcess, let process, process.isRunning {
                    process.terminate()
                }
            }
            let wentDown = await waitForBackendDown(timeoutSeconds: 5)
            if !wentDown {
                TraceLogger.log("backend manager: existing backend failed to exit")
                return .failure(.exitFailed)
            }
        }

        guard let orchestratorDir = findOrchestratorDirectory() else {
            TraceLogger.log("backend manager: failed to locate orchestrator directory")
            return .failure(.repoRootNotFound)
        }
        TraceLogger.log("backend manager: orchestrator dir \(orchestratorDir.path)")

        let venvState = await ensureCompatibleVenv(in: orchestratorDir)
        guard venvState.ok else {
            let reason = venvState.reason ?? "venv setup failed"
            TraceLogger.log("backend manager: venv setup failed: \(reason)")
            if reason.contains("Python 3.9+") {
                return .failure(.pythonNotFound)
            }
            return .failure(.bootstrapFailed(reason))
        }
        let pythonPath = orchestratorDir.appendingPathComponent(".venv/bin/python")

        let dependencyCheck = await ensureDependencies(in: orchestratorDir)
        if !dependencyCheck.ok {
            let reason = dependencyCheck.reason ?? "dependency setup failed"
            TraceLogger.log("backend manager: dependency setup failed: \(reason)")
            return .failure(.bootstrapFailed(reason))
        }

        if await isBackendHealthy() {
            TraceLogger.log("backend manager: backend became healthy before launch")
            ownsProcess = false
            return .success(baseURL)
        }

        guard launchBackend(pythonPath: pythonPath, workingDirectory: orchestratorDir) else {
            TraceLogger.log("backend manager: launch process failed")
            return .failure(.launchFailed)
        }

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if await isBackendHealthy() {
                TraceLogger.log("backend manager: backend healthy after launch")
                return .success(baseURL)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        TraceLogger.log("backend manager: health timeout after launch")
        stop()
        return .failure(.healthTimeout)
    }

    func stop() {
        TraceLogger.log("backend manager: stopping managed backend process")

        let requested = requestExitSync()
        if requested {
            _ = waitForBackendDownSync(timeoutSeconds: 4)
        }

        if ownsProcess, let process, process.isRunning {
            process.terminate()
        }

        self.process = nil
        ownsProcess = false
    }

    private func findOrchestratorDirectory() -> URL? {
        let fm = FileManager.default
        let envRoot = ProcessInfo.processInfo.environment["DICTATOR_REPO_ROOT"]
        if let envRoot {
            let candidate = URL(fileURLWithPath: envRoot).appendingPathComponent("services/orchestrator")
            if fm.fileExists(atPath: candidate.appendingPathComponent("app/main.py").path) {
                return candidate
            }
        }

        var current = URL(fileURLWithPath: fm.currentDirectoryPath)
        while true {
            let candidate = current.appendingPathComponent("services/orchestrator")
            if fm.fileExists(atPath: candidate.appendingPathComponent("app/main.py").path) {
                return candidate
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return nil
    }

    private func ensureCompatibleVenv(in orchestratorDir: URL) async -> (ok: Bool, reason: String?) {
        let venvPythonPath = orchestratorDir.appendingPathComponent(".venv/bin/python").path
        if FileManager.default.fileExists(atPath: venvPythonPath) {
            let currentVenvVersion = await pythonVersion(executable: ".venv/bin/python", cwd: orchestratorDir)
            if let currentVenvVersion, isSupportedPythonVersion(currentVenvVersion) {
                TraceLogger.log("backend manager: using existing venv python \(currentVenvVersion)")
                return (true, nil)
            }

            TraceLogger.log("backend manager: recreating incompatible venv (found \(currentVenvVersion ?? "unknown"))")
            let removeResult = await runProcess(
                executable: "/bin/rm",
                arguments: ["-rf", ".venv"],
                cwd: orchestratorDir
            )
            if removeResult.exitCode != 0 {
                return (false, "failed to remove incompatible .venv")
            }
        }

        guard let pythonExecutable = await selectBootstrapPythonExecutable(cwd: orchestratorDir) else {
            return (false, "Python 3.9+ not found on PATH")
        }
        TraceLogger.log("backend manager: creating .venv with \(pythonExecutable)")

        let venvResult = await runProcess(
            executable: "/usr/bin/env",
            arguments: [pythonExecutable, "-m", "venv", ".venv"],
            cwd: orchestratorDir
        )
        guard venvResult.exitCode == 0 else {
            return (false, "failed to create .venv with \(pythonExecutable): \(summarize(venvResult.output))")
        }

        return (true, nil)
    }

    private func ensureDependencies(in orchestratorDir: URL) async -> (ok: Bool, reason: String?) {
        let importCheck = await runProcess(
            executable: ".venv/bin/python",
            arguments: ["-c", "import fastapi, uvicorn, whisper"],
            cwd: orchestratorDir
        )
        if importCheck.exitCode == 0 {
            clearInstallFailureMarker(orchestratorDir: orchestratorDir)
            return (true, nil)
        }

        if let cachedFailure = recentInstallFailure(orchestratorDir: orchestratorDir) {
            TraceLogger.log("backend manager: skipping reinstall due cached failure: \(cachedFailure)")
            return (false, cachedFailure)
        }

        TraceLogger.log("backend manager: installing orchestrator deps in venv")
        let pipResult = await runProcess(
            executable: ".venv/bin/python",
            arguments: ["-m", "pip", "install", "--disable-pip-version-check", "--no-input", ".[dev]"],
            cwd: orchestratorDir
        )
        if pipResult.exitCode != 0 {
            let reason = "pip install .[dev] failed: \(summarize(pipResult.output))"
            writeInstallFailureMarker(orchestratorDir: orchestratorDir, reason: reason)
            return (false, reason)
        }
        clearInstallFailureMarker(orchestratorDir: orchestratorDir)
        return (true, nil)
    }

    private func selectBootstrapPythonExecutable(cwd: URL) async -> String? {
        let candidates = ["python3.12", "python3.11", "python3.10", "python3"]
        for candidate in candidates {
            let version = await pythonVersion(executable: candidate, cwd: cwd)
            if let version, isSupportedPythonVersion(version) {
                return candidate
            }
        }
        return nil
    }

    private func pythonVersion(executable: String, cwd: URL) async -> String? {
        let result = await runProcess(
            executable: "/usr/bin/env",
            arguments: [executable, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"],
            cwd: cwd
        )
        guard result.exitCode == 0 else {
            return nil
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSupportedPythonVersion(_ version: String) -> Bool {
        Self.isSupportedPythonVersionString(version)
    }

    static func isSupportedPythonVersionString(_ version: String) -> Bool {
        let parts = version.split(separator: ".")
        guard parts.count >= 2, let major = Int(parts[0]), let minor = Int(parts[1]) else {
            return false
        }
        return major > 3 || (major == 3 && minor >= 9)
    }

    private func launchBackend(pythonPath: URL, workingDirectory: URL) -> Bool {
        let process = Process()
        process.executableURL = pythonPath
        process.currentDirectoryURL = workingDirectory
        process.arguments = [
            "-m", "uvicorn", "app.main:app", "--host", host, "--port", String(port)
        ]

        let logURL = URL(fileURLWithPath: "/tmp/dictator-backend.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            return false
        }
        _ = try? logHandle.seekToEnd()
        process.standardOutput = logHandle
        process.standardError = logHandle

        do {
            try process.run()
            self.process = process
            self.ownsProcess = true
            TraceLogger.log("backend manager: launched backend pid=\(process.processIdentifier)")
            return true
        } catch {
            return false
        }
    }

    private func runProcess(executable: String, arguments: [String], cwd: URL) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            let executableURL: URL
            if executable.hasPrefix("/") {
                executableURL = URL(fileURLWithPath: executable)
            } else {
                executableURL = cwd.appendingPathComponent(executable)
            }
            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = cwd

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("dictator-backend-bootstrap-\(UUID().uuidString).log")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            guard let outputHandle = try? FileHandle(forWritingTo: outputURL) else {
                continuation.resume(returning: (exitCode: -1, output: "failed to open bootstrap log file"))
                return
            }
            process.standardOutput = outputHandle
            process.standardError = outputHandle

            do {
                try process.run()
            } catch {
                try? outputHandle.close()
                continuation.resume(returning: (exitCode: -1, output: "failed to run \(executable): \(error)"))
                return
            }

            process.terminationHandler = { proc in
                try? outputHandle.close()
                let data = (try? Data(contentsOf: outputURL)) ?? Data()
                let output = String(data: data, encoding: .utf8) ?? ""
                try? FileManager.default.removeItem(at: outputURL)
                continuation.resume(returning: (exitCode: proc.terminationStatus, output: output))
            }

            Task.detached {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                if process.isRunning {
                    TraceLogger.log("backend manager: bootstrap command timed out (\(executable) \(arguments.joined(separator: " ")))")
                    process.terminate()
                }
            }
        }
    }

    private func isBackendHealthy() async -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "/health"))
        request.timeoutInterval = 0.8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return decoded?["status"] as? String == "ok"
        } catch {
            return false
        }
    }

    private func requestExit() async -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "/exit"))
        request.httpMethod = "POST"
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func waitForBackendDown(timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !(await isBackendHealthy()) {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return false
    }

    private func requestExitSync() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        var request = URLRequest(url: baseURL.appending(path: "/exit"))
        request.httpMethod = "POST"
        request.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                ok = (200...299).contains(http.statusCode)
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 2.0)
        return ok
    }

    private func isBackendHealthySync() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false
        var request = URLRequest(url: baseURL.appending(path: "/health"))
        request.timeoutInterval = 0.7
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data else {
                return
            }
            let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            healthy = decoded?["status"] as? String == "ok"
        }.resume()
        _ = semaphore.wait(timeout: .now() + 1.0)
        return healthy
    }

    private func waitForBackendDownSync(timeoutSeconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !isBackendHealthySync() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func summarize(_ output: String) -> String {
        let compact = output.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if compact.isEmpty {
            return "no output"
        }
        return String(compact.prefix(220))
    }

    private func writeInstallFailureMarker(orchestratorDir: URL, reason: String) {
        let markerURL = orchestratorDir.appendingPathComponent(Self.installFailureMarker)
        let payload = "\(Date().timeIntervalSince1970)\n\(reason)"
        try? payload.write(to: markerURL, atomically: true, encoding: .utf8)
    }

    private func clearInstallFailureMarker(orchestratorDir: URL) {
        let markerURL = orchestratorDir.appendingPathComponent(Self.installFailureMarker)
        try? FileManager.default.removeItem(at: markerURL)
    }

    private func recentInstallFailure(orchestratorDir: URL) -> String? {
        let markerURL = orchestratorDir.appendingPathComponent(Self.installFailureMarker)
        guard let raw = try? String(contentsOf: markerURL, encoding: .utf8) else {
            return nil
        }
        let lines = raw.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let stampString = lines.first, let stamp = TimeInterval(stampString) else {
            return nil
        }
        if !Self.shouldUseCachedInstallFailure(
            now: Date().timeIntervalSince1970,
            stamp: stamp,
            retryInterval: Self.installRetryIntervalSeconds
        ) {
            return nil
        }
        let reason = lines.count > 1 ? String(lines[1]) : "previous dependency install failed recently"
        return reason
    }

    static func shouldUseCachedInstallFailure(
        now: TimeInterval,
        stamp: TimeInterval,
        retryInterval: TimeInterval
    ) -> Bool {
        now - stamp <= retryInterval
    }
}
