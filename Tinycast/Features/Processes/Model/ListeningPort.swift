import Foundation

/// A TCP port some process on the Mac is listening on, as `netstat -anv` reported it.
struct ListeningPort: Identifiable, Equatable, Sendable {
    enum Holder: Equatable, Sendable {
        /// One of the reader's own processes, which a signal can reach.
        case reader(ProcessIdentity)
        /// Another account's process, root's included: listed, but out of the reader's reach.
        case otherUser(String)
        /// The socket names a pid that has already exited.
        case unknown
    }

    let pid: Int32
    let port: Int
    /// "*" for every interface, else the address bound: "127.0.0.1", "::1".
    var address: String
    /// `netstat` cuts names at 16 characters, so the executable's path names the row when known.
    var command: String
    var path: String?
    var holder: Holder = .unknown

    var id: String { "\(pid):\(port)" }
    var name: String { path.map(ProcessPath.name) ?? command }
    var bundlePath: String? { path.flatMap(ProcessPath.bundle) }

    var identity: ProcessIdentity? {
        if case .reader(let identity) = holder { return identity }
        return nil
    }

    /// Reads `netstat -anv -p tcp`: the listeners only, one row per process and port.
    static func parse(netstatOutput: String) -> [ListeningPort] {
        var ports: [ListeningPort] = []
        var rowByID: [String: Int] = [:]
        for line in netstatOutput.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            // proto, recv-q, send-q, local, foreign, state, rx, tx, rhiwat, shiwat, then process:pid.
            guard fields.count > 10, fields[0].hasPrefix("tcp"), fields[5] == "LISTEN",
                let (address, port) = endpoint(fields[3]),
                let ownerEnd = fields[10...].firstIndex(where: { pidSuffix($0) != nil }),
                let pid = pidSuffix(fields[ownerEnd]), pid > 0
            else { continue }
            let owner = fields[10...ownerEnd].joined(separator: " ")
            let command = String(owner[..<(owner.lastIndex(of: ":") ?? owner.endIndex)])
            let listener = ListeningPort(pid: pid, port: port, address: address, command: command)
            // IPv4 and IPv6 listeners on one port are one row to the reader; any wildcard wins.
            if let row = rowByID[listener.id] {
                if address == "*" { ports[row].address = "*" }
                continue
            }
            rowByID[listener.id] = ports.count
            ports.append(listener)
        }
        return ports.sorted { ($0.port, $0.pid) < ($1.port, $1.pid) }
    }

    /// `127.0.0.1.5000`, `::1.5000`, `*.8080`: the port follows the last dot.
    private static func endpoint(_ field: Substring) -> (String, Int)? {
        guard let dot = field.lastIndex(of: "."), let port = Int(field[field.index(after: dot)...]),
            port > 0
        else { return nil }
        return (String(field[..<dot]), port)
    }

    private static func pidSuffix(_ field: Substring) -> Int32? {
        guard let colon = field.lastIndex(of: ":") else { return nil }
        let digits = field[field.index(after: colon)...]
        guard !digits.isEmpty, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
        return Int32(digits)
    }
}
