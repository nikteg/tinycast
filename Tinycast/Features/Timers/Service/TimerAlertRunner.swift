import AppKit
import UserNotifications

/// Each running timer's banner, scheduled ahead so it lands even mid-sleep, and the chime.
@MainActor
final class TimerAlertRunner: NSObject, UNUserNotificationCenterDelegate {
    private static let prefix = "timer."

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized: Bool?
    private lazy var chime = NSSound(named: "Glass")

    override init() {
        super.init()
        // Shared with Pomodoro's runner, which answers the same: whichever is last presents both.
        center.delegate = self
    }

    func schedule(_ timer: CountdownTimer) async {
        cancel(timer.id)
        guard let endsAt = timer.endsAt, await authorize(), !Task.isCancelled else { return }
        let content = UNMutableNotificationContent()
        content.title = timer.label.isEmpty ? "Time's up" : timer.label
        content.body = "Your \(DurationText.spoken(timer.duration)) timer is done."
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endsAt.timeIntervalSinceNow), repeats: false)
        try? await center.add(
            UNNotificationRequest(
                identifier: Self.prefix + timer.id.uuidString, content: content, trigger: trigger))
    }

    func cancel(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.prefix + id.uuidString])
    }

    func chimeNow() {
        chime?.stop()
        chime?.play()
    }

    /// Asked once, on the first timer started, rather than at launch.
    private func authorize() async -> Bool {
        if let isAuthorized { return isAuthorized }
        let granted = (try? await center.requestAuthorization(options: [.alert])) ?? false
        isAuthorized = granted
        return granted
    }

    /// An accessory app counts as frontmost while the palette is up, which hides the banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
