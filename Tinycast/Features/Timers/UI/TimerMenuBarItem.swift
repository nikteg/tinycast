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

struct TimerMenuBarMenu: View {
    private var coordinator: TimerCoordinator { AppCore.shared.timerCoordinator }

    var body: some View {
        ForEach(coordinator.timers) { timer in
            let left = DurationText.countdown(timer.remaining(now: coordinator.now))
            Menu("\(timer.title) · \(timer.isRunning ? left : "Paused at \(left)")") {
                Button(timer.isRunning ? "Pause" : "Resume") { coordinator.togglePause(timer.id) }
                Button("Restart") { coordinator.restart(timer.id) }
                Button("Stop") { coordinator.stop(timer.id) }
            }
        }
        Divider()
        Button("Start Timer…") { coordinator.show() }
        Button("Stop All Timers") { coordinator.stopAll() }
    }
}
