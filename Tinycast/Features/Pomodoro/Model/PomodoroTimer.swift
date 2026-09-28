import Foundation

/// Which half of Mater's cycle the timer is in.
enum PomodoroPhase: String, Codable, Sendable {
    case work
    case rest

    var next: PomodoroPhase { self == .work ? .rest : .work }
}

/// How long each half runs, clamped to Mater's own ranges.
struct PomodoroDurations: Equatable, Sendable {
    static let workRange = 1...60
    static let restRange = 1...30
    static let standard = PomodoroDurations(workMinutes: 25, restMinutes: 5)

    let workMinutes: Int
    let restMinutes: Int

    init(workMinutes: Int, restMinutes: Int) {
        self.workMinutes = min(max(workMinutes, Self.workRange.lowerBound), Self.workRange.upperBound)
        self.restMinutes = min(max(restMinutes, Self.restRange.lowerBound), Self.restRange.upperBound)
    }

    func seconds(of phase: PomodoroPhase) -> TimeInterval {
        TimeInterval((phase == .work ? workMinutes : restMinutes) * 60)
    }
}

/// A running or paused cycle. Stopped is the absence of one.
struct PomodoroTimer: Codable, Equatable, Sendable {
    enum Clock: Codable, Equatable, Sendable {
        case running(endsAt: Date)
        case paused(remaining: TimeInterval)
    }

    private(set) var phase: PomodoroPhase
    private(set) var clock: Clock

    /// A fresh cycle always opens on work, the way Mater winds up to its full work length.
    static func start(now: Date, durations: PomodoroDurations) -> PomodoroTimer {
        PomodoroTimer(phase: .work, clock: .running(endsAt: now + durations.seconds(of: .work)))
    }

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

    /// Whole minutes left, rounded up like Mater's menu-bar count: 24:01 still reads 25.
    func minutesLeft(now: Date) -> Int {
        Int((remaining(now: now) / 60).rounded(.up))
    }

    mutating func pause(now: Date) {
        guard case .running = clock else { return }
        clock = .paused(remaining: remaining(now: now))
    }

    mutating func resume(now: Date) {
        guard case .paused(let remaining) = clock else { return }
        clock = .running(endsAt: now + remaining)
    }

    /// Ends the current phase now and opens the next at its full length, running or not.
    mutating func skip(now: Date, durations: PomodoroDurations) {
        phase = phase.next
        let length = durations.seconds(of: phase)
        clock = isRunning ? .running(endsAt: now + length) : .paused(remaining: length)
    }

    /// Rolls past every ended phase, each from where the last ended; answers where it landed.
    mutating func advance(now: Date, durations: PomodoroDurations) -> PomodoroPhase? {
        guard case .running(var endsAt) = clock, endsAt <= now else { return nil }
        // A Mac asleep through several phases lands on the one the wall clock is in, not the next.
        while endsAt <= now {
            phase = phase.next
            endsAt += durations.seconds(of: phase)
        }
        clock = .running(endsAt: endsAt)
        return phase
    }
}
