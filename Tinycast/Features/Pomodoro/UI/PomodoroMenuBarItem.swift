import SwiftUI

/// Reading the coordinator here scopes Observation to this label, not to every scene.
struct PomodoroMenuBarLabel: View {
    let appName: String

    private var coordinator: PomodoroCoordinator { AppCore.shared.pomodoroCoordinator }

    var body: some View {
        if let timer = coordinator.timer, let minutes = coordinator.minutesLeft {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: symbol(for: timer)).accessibilityHidden(true)
                Text("\(minutes)m")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(appName): \(PomodoroMenuBarMenu.status(of: timer, minutes: minutes))")
        }
    }

    private func symbol(for timer: PomodoroTimer) -> String {
        guard timer.isRunning else { return "pause.circle" }
        return timer.phase == .work ? "timer" : "cup.and.saucer"
    }
}

struct PomodoroMenuBarMenu: View {
    private var coordinator: PomodoroCoordinator { AppCore.shared.pomodoroCoordinator }

    var body: some View {
        if let timer = coordinator.timer, let minutes = coordinator.minutesLeft {
            Text(Self.status(of: timer, minutes: minutes))
            Divider()
            Button(timer.isRunning ? "Pause" : "Resume") { coordinator.togglePause() }
            Button(timer.phase == .work ? "Skip to Break" : "Skip to Work") { coordinator.skip() }
            Button("Stop") { coordinator.stop() }
            Divider()
        }
        Button("Pomodoro Settings...") {
            AppCore.shared.settingsCoordinator.showSettings(tab: .pomodoro)
        }
    }

    static func status(of timer: PomodoroTimer, minutes: Int) -> String {
        let phase = timer.phase == .work ? "Work" : "Break"
        let left = "\(PomodoroAnnouncement.minutes(minutes)) left"
        return timer.isRunning ? "\(phase) · \(left)" : "\(phase) paused · \(left)"
    }
}
