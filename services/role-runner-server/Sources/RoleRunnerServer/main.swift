import Foundation
import Network
import RoleRunnerCore

private func httpStatusText(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 400: return "Bad Request"
    case 404: return "Not Found"
    case 405: return "Method Not Allowed"
    case 409: return "Conflict"
    case 500: return "Internal Server Error"
    default: return "Internal Server Error"
    }
}

private func makeHTTPResponse(statusCode: Int, body: Data) -> Data {
    var lines = "HTTP/1.1 \(statusCode) \(httpStatusText(statusCode))\r\n"
    lines += "Content-Type: application/json\r\n"
    lines += "Content-Length: \(body.count)\r\n"
    lines += "Connection: close\r\n"
    lines += "\r\n"

    var data = Data(lines.utf8)
    data.append(body)
    return data
}

private func parseRequest(_ data: Data) -> (method: String, path: String, body: Data)? {
    guard let text = String(data: data, encoding: .utf8) else {
        return nil
    }

    let parts = text.components(separatedBy: "\r\n\r\n")
    guard let headerBlock = parts.first else {
        return nil
    }
    let headerLines = headerBlock.components(separatedBy: "\r\n")
    guard let requestLine = headerLines.first else {
        return nil
    }
    let requestParts = requestLine.split(separator: " ")
    guard requestParts.count >= 2 else {
        return nil
    }

    let method = String(requestParts[0])
    let path = String(requestParts[1])

    let bodyData: Data
    if parts.count > 1 {
        bodyData = Data(parts[1...].joined(separator: "\r\n\r\n").utf8)
    } else {
        bodyData = Data()
    }

    return (method: method, path: path, body: bodyData)
}

private let repoRoot = ProcessInfo.processInfo.environment["REPO_ROOT"] ?? FileManager.default.currentDirectoryPath
private let scriptPath = ProcessInfo.processInfo.environment["RUN_ROLE_SCRIPT"] ?? "\(repoRoot)/scripts/run-role.sh"
private let portString = ProcessInfo.processInfo.environment["PORT"] ?? "8787"
private let port = NWEndpoint.Port(rawValue: UInt16(portString) ?? 8787) ?? 8787

let service = RunRoleService(repoRoot: repoRoot, scriptPath: scriptPath, executor: ProcessScriptExecutor())

let listener: NWListener

do {
    listener = try NWListener(using: .tcp, on: port)
} catch {
    fputs("failed to start listener: \(error)\n", stderr)
    exit(1)
}

listener.newConnectionHandler = { connection in
    connection.start(queue: .global())

    connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, _, _ in
        let response: HTTPResponse

        guard let raw = data, let request = parseRequest(raw) else {
            response = HTTPResponse(statusCode: 400, body: Data("{\"error\":\"invalid http request\"}".utf8))
            connection.send(content: makeHTTPResponse(statusCode: response.statusCode, body: response.body), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        if request.path != "/run-role" {
            response = HTTPResponse(statusCode: 404, body: Data("{\"error\":\"not found\"}".utf8))
        } else if request.method != "POST" {
            response = HTTPResponse(statusCode: 405, body: Data("{\"error\":\"method not allowed\"}".utf8))
        } else {
            response = service.handleRunRole(body: request.body)
        }

        connection.send(content: makeHTTPResponse(statusCode: response.statusCode, body: response.body), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

listener.start(queue: .global())
print("RoleRunnerServer listening on port \(port.rawValue)")
dispatchMain()
