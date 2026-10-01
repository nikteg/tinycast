import SwiftUI

/// The soonest countdown. Reading the coordinator here scopes Observation to this label.
struct TimerMenuBarLabel: View {
    let appName: String

    private var coordinator: TimerCoordinator { AppCore.shared.timerCoordinator }

    var body: some View {
        if let timer = coordinator.timers.first {
            let left = DurationText.countdown(timer.remaining(now: coordinator.now))
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: timer.isRunning ? "timer" : "pause.circle")
                    .accessibilityHidden(true)
                Text(left).monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(appName): \(timer.title), \(left) left")
        }
    }
}

/// Reads no ticking clock: a title that changed every second would rebuild an open submenu.
struct TimerMenuBarMenu: View {
    private var coordinator: TimerCoordinator { AppCore.shared.timerCoordinator }

    var body: some View {
        ForEach(coordinator.timers) { timer in
            Menu("\(timer.title) · \(Self.status(of: timer))") {
                Button(timer.isRunning ? "Pause" : "Resume") { coordinator.togglePause(timer.id) }
                Button("Restart") { coordinator.restart(timer.id) }
                Button("Stop") { coordinator.stop(timer.id) }
            }
        }
        Divider()
        Button("Start Timer…") { coordinator.show() }
        Button("Stop All Timers") { coordinator.stopAll() }
    }

    /// The end for a running timer, the time left for a paused one: neither moves on its own.
    private static func status(of timer: CountdownTimer) -> String {
        guard let endsAt = timer.endsAt else {
            return "Paused, \(DurationText.countdown(timer.remaining(now: Date()))) left"
        }
        return "ends \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
}
