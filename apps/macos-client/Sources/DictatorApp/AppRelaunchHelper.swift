import Darwin
import Foundation

enum AppRelaunchHelper {
    static let helperFlag = "--relaunch-helper"

    static func maybeRunFromCommandLine(arguments: [String]) -> Bool {
        guard arguments.count >= 4, arguments[1] == helperFlag else {
            return false
        }

        guard let pid = Int32(arguments[2]) else {
            fputs("relaunch helper: invalid pid\n", stderr)
            return true
        }

        let executablePath = arguments[3]
        let relaunchedArgs = Array(arguments.dropFirst(4))
        waitForExit(pid: pid)
        relaunch(executablePath: executablePath, arguments: relaunchedArgs)
        return true
    }

    static func spawnRelaunchHelper(currentPID: Int32, executablePath: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [helperFlag, String(currentPID), executablePath] + arguments

        do {
            try process.run()
            TraceLogger.log("relaunch helper spawned pid=\(process.processIdentifier)")
            return true
        } catch {
            TraceLogger.log("relaunch helper spawn failed: \(error)")
            return false
        }
    }

    private static func waitForExit(pid: Int32) {
        while kill(pid, 0) == 0 {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private static func relaunch(executablePath: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            fputs("relaunch helper: failed to relaunch: \(error)\n", stderr)
        }
    }
}
