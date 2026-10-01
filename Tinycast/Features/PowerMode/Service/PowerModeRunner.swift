import Foundation

/// Reads and sets the battery's Energy Mode through `pmset`, which needs root to write.
enum PowerModeRunner {
    enum Outcome: Sendable {
        case changed
        case cancelled
        case failed
    }

    nonisolated static func batteryMode() -> PowerMode? {
        let (status, output) = run("/usr/bin/pmset", ["-g", "custom"])
        return status == 0 ? PowerMode.battery(pmsetCustom: output) : nil
    }

    /// A sudoers rule for pmset skips the password; without one, macOS asks for an admin's.
    nonisolated static func setBattery(_ mode: PowerMode) -> Outcome {
        let pmset = ["/usr/bin/pmset", "-b", "powermode", String(mode.rawValue)]
        if run("/usr/bin/sudo", ["-n"] + pmset).status == 0 { return .changed }
        let script = "do shell script \"\(pmset.joined(separator: " "))\" with administrator privileges"
        let (status, output) = run("/usr/bin/osascript", ["-e", script])
        if status == 0 { return .changed }
        // -128 is AppleScript's "User canceled".
        return output.contains("-128") ? .cancelled : .failed
    }

    /// Output is drained before the exit is awaited, so a full pipe can never stall the child.
    nonisolated private static func run(
        _ path: String, _ arguments: [String]
    ) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard let exit = try? process.runObservingExit() else { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        exit.wait()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }
}
