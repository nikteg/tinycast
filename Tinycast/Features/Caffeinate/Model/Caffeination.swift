import Foundation

/// How long the Mac is kept awake: until turned off, or until a moment on the wall clock.
enum Caffeination: Equatable, Sendable {
    case indefinitely
    case until(Date)

    /// The lengths offered before anything is typed; nil is "until turned off".
    static let presets: [TimeInterval?] = [nil, 15 * 60, 30 * 60, 3600, 2 * 3600, 4 * 3600, 8 * 3600]

    static func lasting(_ seconds: TimeInterval?, now: Date) -> Caffeination {
        seconds.map { .until(now + $0) } ?? .indefinitely
    }

    var endsAt: Date? {
        if case .until(let date) = self { return date }
        return nil
    }

    func hasEnded(now: Date) -> Bool {
        endsAt.map { $0 <= now } ?? false
    }

    /// `until` is the end, already formatted for the reader's clock.
    func status(until: String?) -> String {
        guard endsAt != nil, let until else { return "Caffeinated until turned off" }
        return "Caffeinated until \(until)"
    }

    static func title(for seconds: TimeInterval?) -> String {
        seconds.map { "Caffeinate for \(DurationText.spoken($0))" } ?? "Caffeinate Until Turned Off"
    }
}
