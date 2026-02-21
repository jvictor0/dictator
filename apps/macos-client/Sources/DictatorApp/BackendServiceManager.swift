import Foundation

final class BackendServiceManager {
    enum BackendError: Error {
        case repoRootNotFound
        case bootstrapFailed(String)
        case launchFailed
        case healthTimeout
    }

    private(set) var baseURL = URL(string: "http://127.0.0.1:8000")!
    private var process: Process?
    private var ownsProcess = false

    func start() async -> Result<URL, BackendError> {
        if await isBackendHealthy() {
            TraceLogger.log("backend manager: using existing backend at \(baseURL.absoluteString)")
            ownsProcess = false
            return .success(baseURL)
        }

        guard let orchestratorDir = findOrchestratorDirectory() else {
            TraceLogger.log("backend manager: failed to locate orchestrator directory")
            return .failure(.repoRootNotFound)
        }
        TraceLogger.log("backend manager: orchestrator dir \(orchestratorDir.path)")

        let pythonPath = orchestratorDir.appendingPathComponent(".venv/bin/python")
        if !FileManager.default.fileExists(atPath: pythonPath.path) {
            TraceLogger.log("backend manager: .venv missing, bootstrapping")
            let setupResult = await runBootstrap(in: orchestratorDir)
            if !setupResult.ok {
                let reason = setupResult.reason ?? "unknown setup failure"
                TraceLogger.log("backend manager: bootstrap failed: \(reason)")
                return .failure(.bootstrapFailed(reason))
            }
        }

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
        guard ownsProcess, let process else {
            return
        }

        TraceLogger.log("backend manager: stopping managed backend process")
        if process.isRunning {
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

    private func runBootstrap(in orchestratorDir: URL) async -> (ok: Bool, reason: String?) {
        let venvResult = await runProcess(
            executable: "/usr/bin/env",
            arguments: ["python3", "-m", "venv", ".venv"],
            cwd: orchestratorDir
        )
        guard venvResult.exitCode == 0 else {
            return (false, "python3 -m venv .venv failed")
        }

        let pipResult = await runProcess(
            executable: ".venv/bin/python",
            arguments: ["-m", "pip", "install", "--disable-pip-version-check", "--no-input", ".[dev]"],
            cwd: orchestratorDir
        )
        guard pipResult.exitCode == 0 else {
            return (false, "pip install .[dev] failed: \(summarize(pipResult.output))")
        }

        return (true, nil)
    }

    private func ensureDependencies(in orchestratorDir: URL) async -> (ok: Bool, reason: String?) {
        let importCheck = await runProcess(
            executable: ".venv/bin/python",
            arguments: ["-c", "import fastapi, uvicorn"],
            cwd: orchestratorDir
        )
        if importCheck.exitCode == 0 {
            return (true, nil)
        }

        TraceLogger.log("backend manager: installing orchestrator deps in existing venv")
        let pipResult = await runProcess(
            executable: ".venv/bin/python",
            arguments: ["-m", "pip", "install", "--disable-pip-version-check", "--no-input", ".[dev]"],
            cwd: orchestratorDir
        )
        if pipResult.exitCode != 0 {
            return (false, "pip install .[dev] failed: \(summarize(pipResult.output))")
        }
        return (true, nil)
    }

    private func launchBackend(pythonPath: URL, workingDirectory: URL) -> Bool {
        let process = Process()
        process.executableURL = pythonPath
        process.currentDirectoryURL = workingDirectory
        process.arguments = [
            "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000"
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
                try? await Task.sleep(nanoseconds: 90_000_000_000)
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

    private func summarize(_ output: String) -> String {
        let compact = output.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if compact.isEmpty {
            return "no output"
        }
        return String(compact.prefix(220))
    }
}
