import Foundation

/// Reads the reader's own processes from `ps` and their listening sockets from `lsof`.
enum ProcessSweep {
    nonisolated static func processes() -> [RunningProcess] {
        // `-ww` stops `ps` cutting a long path at the terminal's width, which it assumes is 80.
        let output = run("/bin/ps", ["-x", "-ww", "-o", "pid=,pcpu=,rss=,comm="])
        return RunningProcess.ordered(RunningProcess.parse(psOutput: output))
    }

    nonisolated static func ports() -> [ListeningPort] {
        let user = String(getuid())
        let output = run(
            "/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-u", user, "-F", "pcn"])
        return ListeningPort.parse(lsofOutput: output)
    }

    /// Output is drained before the exit is awaited, so a full pipe can never stall the child.
    nonisolated private static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard let exit = try? process.runObservingExit() else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        exit.wait()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
