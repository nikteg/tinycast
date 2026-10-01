import SwiftUI

@main
struct TinycastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // Channel-aware: "Tinycast", "Tinycast Dev", or "Tinycast Beta".
    private let appName = Bundle.main.appDisplayName

    /// Independent items: one preference each, no state any can read off another.
    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertion) {
            MenuBarMenu(appName: appName)
        } label: {
            MenuBarLabel(appName: appName)
        }
        .commands { menuBarCommands }

        MenuBarExtra(isInserted: calendarMenuBarInsertion) {
            CalendarMenuBarMenu()
        } label: {
            CalendarMenuBarLabel(appName: appName)
        }

        MenuBarExtra(isInserted: pomodoroMenuBarInsertion) {
            PomodoroMenuBarMenu()
        } label: {
            PomodoroMenuBarLabel(appName: appName)
        }

        MenuBarExtra(isInserted: timerMenuBarInsertion) {
            TimerMenuBarMenu()
        } label: {
            TimerMenuBarLabel(appName: appName)
        }

        MenuBarExtra(isInserted: caffeinateMenuBarInsertion) {
            CaffeinateMenuBarMenu()
        } label: {
            CaffeinateMenuBarLabel(appName: appName)
        }
    }

    /// Read in `body` for Observation; SwiftUI echoes the binding back, so only a change writes.
    private var menuBarInsertion: Binding<Bool> {
        let settings = AppCore.shared.settings
        let isInserted = settings.showInMenuBar
        return Binding(
            get: { isInserted },
            set: { inserted in
                guard inserted != settings.showInMenuBar else { return }
                settings.showInMenuBar = inserted
            })
    }

    /// Writes through `AppSettings`: dragging the item out must stop the clock and move the picker.
    private var calendarMenuBarInsertion: Binding<Bool> {
        let settings = AppCore.shared.settings
        let isInserted = settings.calendarMenuBarDisplay != .disabled && !isCalendarMenuBarHiddenWhenEmpty
        return Binding(
            get: { isInserted },
            set: { inserted in
                if inserted {
                    guard settings.calendarMenuBarDisplay == .disabled else { return }
                    settings.calendarMenuBarDisplay = .meetingIcon
                } else {
                    // SwiftUI echoes our own removal back here; only a drag-out means "turn it off".
                    guard !isCalendarMenuBarHiddenWhenEmpty, settings.calendarMenuBarDisplay != .disabled
                    else { return }
                    settings.calendarMenuBarDisplay = .disabled
                }
            })
    }

    /// Shown only while a cycle exists; dragging it out turns the countdown off.
    private var pomodoroMenuBarInsertion: Binding<Bool> {
        let settings = AppCore.shared.settings
        let isInserted = settings.pomodoroMenuBarEnabled && AppCore.shared.pomodoroStore.timer != nil
        return Binding(
            get: { isInserted },
            set: { inserted in
                guard !inserted, isInserted else { return }
                settings.pomodoroMenuBarEnabled = false
            })
    }

    /// Shown while a timer exists; dragging it out hides it until the next timer starts.
    private var timerMenuBarInsertion: Binding<Bool> {
        let coordinator = AppCore.shared.timerCoordinator
        let isInserted = !coordinator.isMenuBarDismissed && !AppCore.shared.timerStore.timers.isEmpty
        return Binding(
            get: { isInserted },
            set: { inserted in
                guard !inserted, isInserted else { return }
                coordinator.isMenuBarDismissed = true
            })
    }

    /// Shown while caffeinated; dragging it out hides it until the next caffeination.
    private var caffeinateMenuBarInsertion: Binding<Bool> {
        let coordinator = AppCore.shared.caffeinateCoordinator
        let isInserted = !coordinator.isMenuBarDismissed && coordinator.caffeination != nil
        return Binding(
            get: { isInserted },
            set: { inserted in
                guard !inserted, isInserted else { return }
                coordinator.isMenuBarDismissed = true
            })
    }

    /// Read in `body`, so Observation re-runs the scene when the coordinator's flag flips.
    private var isCalendarMenuBarHiddenWhenEmpty: Bool {
        AppCore.shared.settings.calendarMenuBarHidesWhenEmpty
            && !AppCore.shared.calendarCoordinator.hasMenuBarEvent
    }

    /// Declared, not assigned to `NSApp.mainMenu`: SwiftUI rebuilds the menu on any scene change.
    @CommandsBuilder
    private var menuBarCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(appName)") { AppCore.shared.settingsCoordinator.showAbout() }
            Button("Check for Updates…") { AppCore.shared.updateCoordinator.checkForUpdates() }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { AppCore.shared.settingsCoordinator.showSettings() }
                .keyboardShortcut(",")
        }
        CommandGroup(replacing: .appTermination) {
            Button("Close Window") {
                // The chat window closes itself when it is in front; otherwise ⌘Q is Settings'.
                guard !AppCore.shared.aiChatCoordinator.closeWindowIfKey() else { return }
                AppCore.shared.settingsCoordinator.closeSettings()
            }
            .keyboardShortcut("q")
        }
    }
}
