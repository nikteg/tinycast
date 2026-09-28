import SwiftUI

struct PomodoroSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Stepper(value: $settings.pomodoroWorkMinutes, in: PomodoroDurations.workRange) {
                    SettingsRowTitle(.pomodoroTimer, "Work Length")
                    Text(PomodoroAnnouncement.minutes(settings.pomodoroWorkMinutes))
                }
                Stepper(value: $settings.pomodoroRestMinutes, in: PomodoroDurations.restRange) {
                    SettingsRowTitle(.pomodoroTimer, "Break Length")
                    Text(PomodoroAnnouncement.minutes(settings.pomodoroRestMinutes))
                }
            } header: {
                SettingsSectionHeader(.pomodoroTimer)
            } footer: {
                Text("Work and breaks alternate until you stop. A new length applies from the next phase.")
            }

            Section {
                Toggle(isOn: $settings.pomodoroNotificationsEnabled) {
                    SettingsRowTitle(.pomodoroAlerts, "Show Notifications")
                    Text("When it is time for a break, and when the break is over.")
                }
                Toggle(isOn: $settings.pomodoroSoundsEnabled) {
                    SettingsRowTitle(.pomodoroAlerts, "Play Sounds")
                    Text("A ding as a phase ends, and a wind-up as the next begins.")
                }
            } header: {
                SettingsSectionHeader(.pomodoroAlerts)
            }

            Section {
                Toggle(isOn: $settings.pomodoroMenuBarEnabled) {
                    SettingsRowTitle(.pomodoroMenuBar, "Countdown in Menu Bar")
                    Text("While a Pomodoro is running or paused.")
                }
            } header: {
                SettingsSectionHeader(.pomodoroMenuBar)
            }

            FeatureCommandsSection(owner: .pomodoro, anchor: .pomodoroCommands)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.pomodoro)
    }
}
