import Foundation

/// The line `uptime` prints: the clock, the time since boot, signed-in sessions and load averages.
struct UptimeReport: Equatable, Sendable {
    /// Already formatted for the reader's clock.
    let clock: String
    let sinceBoot: TimeInterval
    let users: Int
    let loadAverages: [Double]

    var line: String {
        let loads = loadAverages.map { String(format: "%.2f", $0) }.joined(separator: " ")
        return "\(clock) up \(Self.span(sinceBoot)), \(users) user\(users == 1 ? "" : "s"), "
            + "load averages: \(loads)"
    }

    /// BSD `w`'s wording, including its rounding to the nearest minute once past the first.
    static func span(_ seconds: TimeInterval) -> String {
        var total = max(Int(seconds), 0)
        if total > 60 { total += 30 }
        let days = total / 86_400
        let hours = total % 86_400 / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        var parts: [String] = []
        if days > 0 { parts.append(counted(days, "day")) }
        if hours > 0, minutes > 0 {
            parts.append("\(hours):" + String(format: "%02d", minutes))
        } else if hours > 0 {
            parts.append(counted(hours, "hr"))
        } else if minutes > 0 {
            parts.append(counted(minutes, "min"))
        } else {
            parts.append(counted(secs, "sec"))
        }
        return parts.joined(separator: ", ")
    }

    private static func counted(_ value: Int, _ unit: String) -> String {
        "\(value) \(unit)\(value > 1 ? "s" : "")"
    }
}
