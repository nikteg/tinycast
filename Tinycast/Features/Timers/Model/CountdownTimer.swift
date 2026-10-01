import Foundation

/// One countdown, running or paused. A timer that has rung is gone, never a third state.
struct CountdownTimer: Codable, Equatable, Identifiable, Sendable {
    enum Clock: Codable, Equatable, Sendable {
        case running(endsAt: Date)
        case paused(remaining: TimeInterval)
    }

    let id: UUID
    let label: String
    let duration: TimeInterval
    private(set) var clock: Clock

    static func start(_ phrase: DurationPhrase, now: Date, id: UUID = UUID()) -> CountdownTimer {
        CountdownTimer(
            id: id, label: phrase.label, duration: phrase.seconds,
            clock: .running(endsAt: now + phrase.seconds))
    }

    /// The typed name, or the length when none was given.
    var title: String { label.isEmpty ? DurationText.spoken(duration) : label }

    var isRunning: Bool {
        if case .running = clock { return true }
        return false
    }

    var endsAt: Date? {
        if case .running(let endsAt) = clock { return endsAt }
        return nil
    }

    func remaining(now: Date) -> TimeInterval {
        switch clock {
        case .running(let endsAt): max(0, endsAt.timeIntervalSince(now))
        case .paused(let remaining): remaining
        }
    }

    func hasEnded(now: Date) -> Bool {
        endsAt.map { $0 <= now } ?? false
    }

    mutating func pause(now: Date) {
        guard case .running = clock else { return }
        clock = .paused(remaining: remaining(now: now))
    }

    mutating func resume(now: Date) {
        guard case .paused(let remaining) = clock else { return }
        clock = .running(endsAt: now + remaining)
    }

    /// Back to the full length, running, whatever state it was in.
    mutating func restart(now: Date) {
        clock = .running(endsAt: now + duration)
    }

    /// Soonest to ring first; paused ones after, least time left first.
    static func ordered(_ timers: [CountdownTimer], now: Date) -> [CountdownTimer] {
        timers.sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
            return lhs.remaining(now: now) < rhs.remaining(now: now)
        }
    }
}
