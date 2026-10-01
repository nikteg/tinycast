import Foundation

/// One of the reader's own processes, as `ps` reported it.
struct RunningProcess: Identifiable, Equatable, Sendable {
    let pid: Int32
    /// Percent of one core, as `ps` averages it; above 100 on a busy multithreaded process.
    let cpu: Double
    let memoryBytes: Int64
    let path: String

    var id: Int32 { pid }

    var name: String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        return last.isEmpty ? path : last
    }

    /// The outermost app bundle, so a helper nested deep in a framework wears its app's icon.
    var bundlePath: String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    /// Reads `ps -o pid=,pcpu=,rss=,comm=`: three numbers, then a path that may hold spaces.
    static func parse(psOutput: String) -> [RunningProcess] {
        psOutput.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4, let pid = Int32(fields[0]), let cpu = Double(fields[1]),
                let kilobytes = Int64(fields[2])
            else { return nil }
            let path = fields[3].trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { return nil }
            return RunningProcess(pid: pid, cpu: cpu, memoryBytes: kilobytes * 1024, path: path)
        }
    }

    /// Busiest first; ties go to the larger, then the older process.
    static func ordered(_ processes: [RunningProcess]) -> [RunningProcess] {
        processes.sorted { lhs, rhs in
            if lhs.cpu != rhs.cpu { return lhs.cpu > rhs.cpu }
            if lhs.memoryBytes != rhs.memoryBytes { return lhs.memoryBytes > rhs.memoryBytes }
            return lhs.pid < rhs.pid
        }
    }
}
