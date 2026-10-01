import Foundation

/// Sends one signal to one process; answers the reason it was refused, or nil once delivered.
enum ProcessSignalRunner {
    static func send(_ signal: Int32, to pid: Int32) -> String? {
        guard kill(pid, signal) != 0 else { return nil }
        return String(cString: strerror(errno))
    }
}
