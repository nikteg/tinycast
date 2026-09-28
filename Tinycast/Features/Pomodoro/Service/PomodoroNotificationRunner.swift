import UserNotifications

/// Schedules each phase change ahead of time, so it lands on the minute even straight after a wake.
@MainActor
final class PomodoroNotificationRunner: NSObject, UNUserNotificationCenterDelegate {
    private static let identifier = "pomodoro.phase-change"

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized: Bool?

    override init() {
        super.init()
        center.delegate = self
    }

    /// Replaces any pending change with this one, due at `date`.
    func schedule(_ announcement: PomodoroAnnouncement, at date: Date) async {
        cancel()
        guard await authorize(), !Task.isCancelled else { return }
        let content = UNMutableNotificationContent()
        content.title = announcement.title
        content.body = announcement.body
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    /// Asked once, on the first cycle started, rather than at launch.
    private func authorize() async -> Bool {
        if let isAuthorized { return isAuthorized }
        let granted = (try? await center.requestAuthorization(options: [.alert])) ?? false
        isAuthorized = granted
        return granted
    }

    /// An accessory app counts as frontmost while the palette is up, which would swallow the banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
