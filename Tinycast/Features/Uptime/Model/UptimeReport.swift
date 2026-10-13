import Foundation

/// How long the Mac has been up, and since when.
struct UptimeReport: Equatable, Sendable {
    let sinceBoot: TimeInterval
    /// The boot moment, already formatted for the reader's clock.
    let booted: String

    var line: String { "Up \(Self.span(sinceBoot)) · since \(booted)" }

    /// "2 days 14 hours 22 minutes": to the minute, so it holds still while the pill is up.
    static func span(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds)) / 60
        let parts = [(minutes / 1440, "day"), (minutes % 1440 / 60, "hour"), (minutes % 60, "minute")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        return parts.isEmpty ? "less than a minute" : parts.joined(separator: " ")
    }
}
