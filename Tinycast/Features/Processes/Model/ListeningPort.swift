import Foundation

/// A TCP port one of the reader's processes is listening on, as `lsof` reported it.
struct ListeningPort: Identifiable, Equatable, Sendable {
    let pid: Int32
    let command: String
    let port: Int
    /// "*" for every interface, else the address bound — "127.0.0.1", "[::1]".
    let address: String

    var id: String { "\(pid):\(port)" }

    /// Reads `lsof -F pcn`: `p` opens a process, `c` names it, each `n` is one socket.
    static func parse(lsofOutput: String) -> [ListeningPort] {
        var ports: [ListeningPort] = []
        var seen = Set<String>()
        var pid: Int32?
        var command = ""
        for line in lsofOutput.split(whereSeparator: \.isNewline) {
            let value = String(line.dropFirst())
            switch line.first {
            case "p":
                pid = Int32(value)
                command = ""
            case "c":
                command = value
            case "n":
                guard let pid, let colon = value.lastIndex(of: ":"),
                    let number = Int(value[value.index(after: colon)...])
                else { continue }
                let listener = ListeningPort(
                    pid: pid, command: command, port: number, address: String(value[..<colon]))
                // IPv4 and IPv6 listeners on one port are one row to the reader.
                guard seen.insert(listener.id).inserted else { continue }
                ports.append(listener)
            default:
                continue
            }
        }
        return ports.sorted { ($0.port, $0.pid) < ($1.port, $1.pid) }
    }
}
