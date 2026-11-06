import Foundation

/// A pid and when it started: a pid is reused once its process exits, the pair never is.
struct ProcessIdentity: Hashable, Sendable {
    let pid: Int32
    /// Microseconds since 1970, as the kernel records the process's start.
    let startedAt: UInt64
}

/// One process as the kernel reported it, its CPU still a running total rather than a share.
struct ProcessSample: Equatable, Sendable {
    let identity: ProcessIdentity
    let path: String
    let cpuNanoseconds: UInt64
    let memoryBytes: Int64
}

/// Every sample of one sweep, and when it was taken on a clock that only moves forward.
struct ProcessReading: Sendable {
    let samples: [ProcessSample]
    let takenAtNanoseconds: UInt64
}

/// One of the reader's own processes, its CPU measured between two readings.
struct RunningProcess: Identifiable, Equatable, Sendable {
    let identity: ProcessIdentity
    let path: String
    /// Percent of one core since the previous reading; above 100 on a busy multithreaded process.
    let cpu: Double
    /// The physical footprint, which is what Activity Monitor calls Memory.
    let memoryBytes: Int64

    var pid: Int32 { identity.pid }
    var id: String { "\(identity.pid)@\(identity.startedAt)" }
    var name: String { ProcessPath.name(path) }
    var bundlePath: String? { ProcessPath.bundle(path) }

    /// A process absent from `previous` started since it, so it has no share to report yet.
    static func measure(_ reading: ProcessReading, since previous: ProcessReading?) -> [RunningProcess] {
        let before = Dictionary(
            (previous?.samples ?? []).map { ($0.identity, $0.cpuNanoseconds) },
            uniquingKeysWith: { first, _ in first })
        let elapsed = previous.map { reading.takenAtNanoseconds &- $0.takenAtNanoseconds } ?? 0
        return reading.samples.map { sample in
            var cpu = 0.0
            if elapsed > 0, elapsed < .max / 2, let earlier = before[sample.identity],
                sample.cpuNanoseconds >= earlier
            {
                cpu = Double(sample.cpuNanoseconds - earlier) / Double(elapsed) * 100
            }
            return RunningProcess(
                identity: sample.identity, path: sample.path, cpu: cpu, memoryBytes: sample.memoryBytes)
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

    /// Shown rows keep their places, so a live refresh never slides a row out from under the reader.
    static func arranged(
        _ fresh: [RunningProcess], keepingOrderOf shown: [RunningProcess]
    ) -> [RunningProcess] {
        guard !shown.isEmpty else { return ordered(fresh) }
        let byID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let kept = shown.compactMap { byID[$0.id] }
        let shownIDs = Set(shown.map(\.id))
        return kept + ordered(fresh.filter { !shownIDs.contains($0.id) })
    }
}

/// What an executable's path says about it: its name, and the app it ships inside.
enum ProcessPath {
    static func name(_ path: String) -> String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        return last.isEmpty ? path : last
    }

    /// The outermost app bundle, so a helper nested deep in a framework wears its app's icon.
    static func bundle(_ path: String) -> String? {
        guard path.hasPrefix("/"), let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
