import XCTest
@testable import RoleRunnerCore

private struct StubExecutor: ScriptExecuting {
    let result: Result<ScriptInvocationResult, Error>

    func run(scriptPath: String, repoRoot: String, request: RunRoleRequest, timeoutSeconds: TimeInterval) throws -> ScriptInvocationResult {
        try result.get()
    }
}

private func makeResponseJSON(status: RunStatus, message: String = "ok") -> Data {
    let response = RunRoleResponse(
        runID: "run-1",
        status: status,
        workItemID: "wi",
        sliceID: "s1",
        role: .architect,
        artifactsWritten: [],
        issuesOpen: [],
        issuesCreated: [],
        nextAllowedRoles: [.implementer],
        message: message
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try! encoder.encode(response)
}

final class RunRoleServiceTests: XCTestCase {
    func testSuccess() {
        let service = RunRoleService(
            repoRoot: "/tmp",
            scriptPath: "/tmp/run-role.sh",
            executor: StubExecutor(result: .success(.init(terminationStatus: 0, stdout: makeResponseJSON(status: .success), stderr: Data())))
        )

        let body = Data("{\"work_item_id\":\"wi\",\"slice_id\":\"s1\",\"role\":\"architect\"}".utf8)
        let result = service.handleRunRole(body: body)
        XCTAssertEqual(result.statusCode, 200)
    }

    func testNotFound() {
        let service = RunRoleService(
            repoRoot: "/tmp",
            scriptPath: "/tmp/run-role.sh",
            executor: StubExecutor(result: .success(.init(terminationStatus: 2, stdout: makeResponseJSON(status: .validationError, message: "slice not found"), stderr: Data())))
        )

        let body = Data("{\"work_item_id\":\"wi\",\"slice_id\":\"s1\",\"role\":\"architect\"}".utf8)
        let result = service.handleRunRole(body: body)
        XCTAssertEqual(result.statusCode, 404)
    }

    func testValidationConflict() {
        let service = RunRoleService(
            repoRoot: "/tmp",
            scriptPath: "/tmp/run-role.sh",
            executor: StubExecutor(result: .success(.init(terminationStatus: 2, stdout: makeResponseJSON(status: .validationError, message: "implementer requires SPEC.md"), stderr: Data())))
        )

        let body = Data("{\"work_item_id\":\"wi\",\"slice_id\":\"s1\",\"role\":\"implementer\"}".utf8)
        let result = service.handleRunRole(body: body)
        XCTAssertEqual(result.statusCode, 409)
    }

    func testExecutionError() {
        let service = RunRoleService(
            repoRoot: "/tmp",
            scriptPath: "/tmp/run-role.sh",
            executor: StubExecutor(result: .success(.init(terminationStatus: 3, stdout: makeResponseJSON(status: .executionError, message: "failed"), stderr: Data())))
        )

        let body = Data("{\"work_item_id\":\"wi\",\"slice_id\":\"s1\",\"role\":\"architect\"}".utf8)
        let result = service.handleRunRole(body: body)
        XCTAssertEqual(result.statusCode, 500)
    }

    func testBadRequest() {
        let service = RunRoleService(
            repoRoot: "/tmp",
            scriptPath: "/tmp/run-role.sh",
            executor: StubExecutor(result: .failure(ScriptExecutionError.timedOut))
        )

        let result = service.handleRunRole(body: Data("{not-json}".utf8))
        XCTAssertEqual(result.statusCode, 400)
    }
}
