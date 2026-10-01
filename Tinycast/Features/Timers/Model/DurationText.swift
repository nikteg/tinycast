import Foundation

/// How a length of time reads: spelled out for a row, or ticking for a countdown.
enum DurationText {
    /// "1 hour 30 minutes", "45 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let parts = [(total / 3600, "hour"), (total % 3600 / 60, "minute"), (total % 60, "second")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }

    /// "4:05", "1:04:05" — rounded up, so it never reads 0:00 while any time is left.
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        let tail = String(format: "%02d", secs)
        guard hours > 0 else { return "\(minutes):\(tail)" }
        return "\(hours):\(String(format: "%02d", minutes)):\(tail)"
    }
}
