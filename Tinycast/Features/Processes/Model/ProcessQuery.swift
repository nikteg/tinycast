import Foundation

/// What a typed query keeps: a name fragment, a pid, or a port — ":3000" or plain "3000".
enum ProcessQuery {
    static func filter(
        _ processes: [RunningProcess], ports: [Int32: [Int]], query: String
    ) -> [RunningProcess] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return processes }
        let number = Int(needle)
        return processes.filter { process in
            if process.name.localizedCaseInsensitiveContains(needle) { return true }
            guard let number else { return false }
            return Int(process.pid) == number || ports[process.pid]?.contains(number) == true
        }
    }

    static func filter(_ ports: [ListeningPort], query: String) -> [ListeningPort] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return ports }
        return ports.filter { port in
            String(port.port).hasPrefix(needle) || String(port.pid) == needle
                || port.command.localizedCaseInsensitiveContains(needle)
        }
    }

    /// Ports by pid, so a process row can say what it listens on.
    static func portsByProcess(_ ports: [ListeningPort]) -> [Int32: [Int]] {
        Dictionary(grouping: ports, by: \.pid).mapValues { $0.map(\.port) }
    }

    private static func normalized(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix(":") ? String(trimmed.dropFirst()) : trimmed
    }
}
