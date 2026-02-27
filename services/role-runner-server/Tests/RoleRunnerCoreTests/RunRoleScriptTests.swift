import Foundation
import XCTest

private enum ScriptTestError: Error {
    case failed(String)
}

private func repoRoot() -> String {
    let fileURL = URL(fileURLWithPath: #filePath)
    let testsDir = fileURL.deletingLastPathComponent()
    let packageDir = testsDir.deletingLastPathComponent().deletingLastPathComponent()
    let servicesDir = packageDir.deletingLastPathComponent()
    return servicesDir.deletingLastPathComponent().path
}

private func runScript(_ args: [String], env: [String: String]) throws -> (status: Int32, json: [String: Any]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: repoRoot() + "/scripts/run-role.sh")
    process.arguments = args

    var mergedEnv = ProcessInfo.processInfo.environment
    for (k, v) in env {
        mergedEnv[k] = v
    }
    process.environment = mergedEnv

    let stdout = Pipe()
    process.standardOutput = stdout
    let stderr = Pipe()
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
    guard let object = try JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw ScriptTestError.failed("missing json output: \(err)")
    }

    return (process.terminationStatus, object)
}

private func write(_ path: String, _ text: String) throws {
    try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path, withIntermediateDirectories: true)
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}

private func createCodexStub(at path: String) throws {
    let script = """
#!/usr/bin/env bash
set -euo pipefail
repo=""
last=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-C" ]]; then
    repo="$2"
    shift 2
  else
    last="$1"
    shift
  fi
done
if [[ -n "$repo" ]]; then
  cd "$repo"
fi
if [[ "$last" == *"role: architect"* ]]; then
  target=$(echo "$last" | sed -n 's/.*target path: \\(.*\\)$/\\1/p' | head -n1)
  mkdir -p "$target"
  if [[ ! -f "$target/SPEC.md" ]]; then
    printf '# spec\\n' > "$target/SPEC.md"
  fi
  printf '# architect\\n' > "$target/architect.md"
elif [[ "$last" == *"role: implementer"* ]]; then
  target=$(echo "$last" | sed -n 's/.*target path: \\(.*\\)$/\\1/p' | head -n1)
  count=$(find "$target" -maxdepth 1 -name 'implementer-pass-*.md' | wc -l | tr -d ' ')
  next=$((count+1))
  printf '# implementer pass %s\\n' "$next" > "$target/implementer-pass-$next.md"
elif [[ "$last" == *"role: reviewer"* ]]; then
  target=$(echo "$last" | sed -n 's/.*target path: \\(.*\\)$/\\1/p' | head -n1)
  count=$(find "$target" -maxdepth 1 -name 'reviewer-pass-*.md' | wc -l | tr -d ' ')
  next=$((count+1))
  printf 'Approved\\n' > "$target/reviewer-pass-$next.md"
elif [[ "$last" == *"role: tester"* ]]; then
  target=$(echo "$last" | sed -n 's/.*target path: \\(.*\\)$/\\1/p' | head -n1)
  printf 'Pass\\n' > "$target/tester.md"
fi
"""
    try write(path, script)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
}

private func makeTempRepo() throws -> String {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    try write(root + "/AGENTS.md", "agents")
    try write(root + "/docs/governance/BYLAWS.md", "bylaws")
    try write(root + "/docs/governance/WORKFLOWS.md", "workflows")
    try write(root + "/docs/governance/ROLE_HANDOFFS.md", "handoffs")
    return root
}

final class RunRoleScriptTests: XCTestCase {
    func testArchitectRunSucceedsOnNewSlice() throws {
        let repo = try makeTempRepo()
        let codex = repo + "/codex-stub.sh"
        try createCodexStub(at: codex)

        try FileManager.default.createDirectory(atPath: repo + "/work-items/wi/slices/s1", withIntermediateDirectories: true)

        let result = try runScript([
            "--work-item", "wi",
            "--slice", "s1",
            "--role", "architect",
            "--repo-root", repo
        ], env: ["CODEX_BIN": codex])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.json["status"] as? String, "success")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repo + "/work-items/wi/slices/s1/architect.md"))
    }

    func testImplementerRequiresSpec() throws {
        let repo = try makeTempRepo()
        try FileManager.default.createDirectory(atPath: repo + "/work-items/wi/slices/s1", withIntermediateDirectories: true)

        let result = try runScript([
            "--work-item", "wi",
            "--slice", "s1",
            "--role", "implementer",
            "--repo-root", repo
        ], env: ["RUN_ROLE_SKIP_EXEC": "1"])

        XCTAssertEqual(result.status, 2)
        XCTAssertTrue((result.json["message"] as? String)?.contains("SPEC.md") == true)
    }

    func testImplementerPassThreeRejected() throws {
        let repo = try makeTempRepo()
        let slice = repo + "/work-items/wi/slices/s1"
        try FileManager.default.createDirectory(atPath: slice, withIntermediateDirectories: true)
        try write(slice + "/SPEC.md", "spec")
        try write(slice + "/implementer-pass-1.md", "one")
        try write(slice + "/implementer-pass-2.md", "two")

        let result = try runScript([
            "--work-item", "wi",
            "--slice", "s1",
            "--role", "implementer",
            "--repo-root", repo
        ], env: ["RUN_ROLE_SKIP_EXEC": "1"])

        XCTAssertEqual(result.status, 2)
        XCTAssertTrue((result.json["message"] as? String)?.contains("pass limit") == true)
    }

    func testImplementerPassTwoWithOpenIssue() throws {
        let repo = try makeTempRepo()
        let codex = repo + "/codex-stub.sh"
        try createCodexStub(at: codex)

        let slice = repo + "/work-items/wi/slices/s1"
        try FileManager.default.createDirectory(atPath: slice + "/issues", withIntermediateDirectories: true)
        try write(slice + "/SPEC.md", "spec")
        try write(slice + "/implementer-pass-1.md", "one")
        try write(slice + "/issues/issue-0001.md", "Issue-ID: 1\nStatus: OPEN\n")

        let result = try runScript([
            "--work-item", "wi",
            "--slice", "s1",
            "--role", "implementer",
            "--repo-root", repo
        ], env: ["CODEX_BIN": codex])

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: slice + "/implementer-pass-2.md"))
    }

    func testRunCleansTempLog() throws {
        let repo = try makeTempRepo()
        let codex = repo + "/codex-stub.sh"
        try createCodexStub(at: codex)

        let slice = repo + "/work-items/wi/slices/s1"
        try FileManager.default.createDirectory(atPath: slice, withIntermediateDirectories: true)

        let result = try runScript([
            "--work-item", "wi",
            "--slice", "s1",
            "--role", "architect",
            "--repo-root", repo
        ], env: ["CODEX_BIN": codex])

        XCTAssertEqual(result.status, 0)
        let runID = result.json["run_id"] as? String
        XCTAssertNotNil(runID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/tmp/run-role-codex-\(runID!).log"))
    }
}
