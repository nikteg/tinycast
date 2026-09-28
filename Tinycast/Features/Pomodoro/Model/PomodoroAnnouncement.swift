import Foundation

/// What a phase change says, in a notification and in the menu bar item.
struct PomodoroAnnouncement: Equatable, Sendable {
    let title: String
    let body: String

    /// `until` is the new phase's end, already formatted for the reader's clock.
    static func entering(_ phase: PomodoroPhase, durations: PomodoroDurations, until: String) -> Self {
        switch phase {
        case .rest:
            PomodoroAnnouncement(
                title: "Time for a break",
                body: "Take \(minutes(durations.restMinutes)) off, until \(until).")
        case .work:
            PomodoroAnnouncement(
                title: "Break's over",
                body: "Back to work for \(minutes(durations.workMinutes)), until \(until).")
        }
    }

    static func minutes(_ count: Int) -> String {
        count == 1 ? "1 minute" : "\(count) minutes"
    }
}
