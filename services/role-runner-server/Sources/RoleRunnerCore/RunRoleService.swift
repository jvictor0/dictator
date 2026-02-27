import Foundation

public enum RequestHandlingError: Error {
    case invalidJSON
    case unsupportedPath
    case unsupportedMethod
}

public final class RunRoleService {
    private let repoRoot: String
    private let scriptPath: String
    private let timeoutSeconds: TimeInterval
    private let executor: ScriptExecuting
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(repoRoot: String, scriptPath: String, timeoutSeconds: TimeInterval = 1200, executor: ScriptExecuting) {
        self.repoRoot = repoRoot
        self.scriptPath = scriptPath
        self.timeoutSeconds = timeoutSeconds
        self.executor = executor

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    public func handleRunRole(body: Data) -> HTTPResponse {
        let request: RunRoleRequest
        do {
            request = try decoder.decode(RunRoleRequest.self, from: body)
        } catch {
            return jsonResponse(statusCode: 400, payload: ["error": "invalid request body"])
        }

        let result: ScriptInvocationResult
        do {
            result = try executor.run(
                scriptPath: scriptPath,
                repoRoot: repoRoot,
                request: request,
                timeoutSeconds: timeoutSeconds
            )
        } catch ScriptExecutionError.timedOut {
            return jsonResponse(statusCode: 500, payload: ["error": "runner timed out"])
        } catch ScriptExecutionError.launchFailed(let message) {
            return jsonResponse(statusCode: 500, payload: ["error": "runner launch failed: \(message)"])
        } catch {
            return jsonResponse(statusCode: 500, payload: ["error": "runner failed"])
        }

        guard let response = try? decoder.decode(RunRoleResponse.self, from: result.stdout) else {
            let stderr = String(data: result.stderr, encoding: .utf8) ?? ""
            return jsonResponse(statusCode: 500, payload: ["error": "runner returned invalid JSON", "stderr": stderr])
        }

        switch response.status {
        case .success:
            return encodeResponse(statusCode: 200, response)
        case .validationError:
            if response.message.lowercased().contains("not found") {
                return encodeResponse(statusCode: 404, response)
            }
            return encodeResponse(statusCode: 409, response)
        case .executionError:
            return encodeResponse(statusCode: 500, response)
        }
    }

    private func encodeResponse(statusCode: Int, _ response: RunRoleResponse) -> HTTPResponse {
        guard let data = try? encoder.encode(response) else {
            return jsonResponse(statusCode: 500, payload: ["error": "failed to encode response"])
        }
        return HTTPResponse(statusCode: statusCode, body: data)
    }

    private func jsonResponse(statusCode: Int, payload: [String: String]) -> HTTPResponse {
        guard let data = try? encoder.encode(payload) else {
            return HTTPResponse(statusCode: 500, body: Data("{\"error\":\"encoding failed\"}".utf8))
        }
        return HTTPResponse(statusCode: statusCode, body: data)
    }
}
