import Foundation

/// Sends one signal to one process, and only while that pid is still the process that was shown.
enum ProcessSignalRunner {
    enum Outcome: Equatable {
        case delivered
        case exited
        case refused(String)
    }

    static func send(_ signal: Int32, to process: ProcessIdentity) -> Outcome {
        guard ProcessSweep.startedAt(process.pid) == process.startedAt else { return .exited }
        guard kill(process.pid, signal) != 0 else { return .delivered }
        let code = errno
        return code == ESRCH ? .exited : .refused(String(cString: strerror(code)))
    }
}
