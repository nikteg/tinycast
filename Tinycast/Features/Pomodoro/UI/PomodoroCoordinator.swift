import Foundation

/// Runs Mater's cycle: the phase clock, its sounds and notifications, and the commands' presence.
@MainActor
@Observable
final class PomodoroCoordinator {
    /// Mater winds the next phase up a beat after the ding, not over it.
    private static let windUpDelay: Duration = .seconds(2)
    private static let runningCommands: Set<CommandID> = [.skipPomodoroPhase, .stopPomodoro]

    private let store: PomodoroStore
    private let settings: AppSettings
    private let appIndex: AppIndex
    /// The HUD, so it stays owned by `AppCore`.
    private unowned let core: AppCore

    @ObservationIgnored private let sounds = PomodoroSoundRunner()
    @ObservationIgnored private let notifications = PomodoroNotificationRunner()
    @ObservationIgnored private var pump: Task<Void, Never>?
    @ObservationIgnored private var windUp: Task<Void, Never>?
    @ObservationIgnored private var announcing: Task<Void, Never>?

    /// Advanced once a minute by the pump, so the menu-bar label re-reads only when its count moves.
    private(set) var now = Date()

    init(store: PomodoroStore, settings: AppSettings, appIndex: AppIndex, core: AppCore) {
        self.store = store
        self.settings = settings
        self.appIndex = appIndex
        self.core = core
    }

    var timer: PomodoroTimer? { store.timer }

    var minutesLeft: Int? { store.timer?.minutesLeft(now: now) }

    /// A cycle left running over a quit picks up on the phase the wall clock is in.
    func start() {
        if var timer = store.timer, timer.advance(now: Date(), durations: durations) != nil {
            store.update(timer)
        }
        applyPresence()
        announceNext()
        runPump()
    }

    func startCycle() {
        store.update(.start(now: Date(), durations: durations))
        playWindUp(minutes: durations.workMinutes, after: nil)
        core.showMessage(
            "Pomodoro started · \(PomodoroAnnouncement.minutes(durations.workMinutes)) of work")
        began()
    }

    /// Starts a cycle when none is running, so one shortcut covers the whole timer.
    func togglePause() {
        guard let timer = store.timer else { return startCycle() }
        if timer.isRunning { pause() } else { resume() }
    }

    func pause() {
        guard var timer = store.timer, timer.isRunning else { return }
        timer.pause(now: Date())
        store.update(timer)
        play(.toggleOff)
        core.showMessage("Pomodoro paused")
        halted()
    }

    func resume() {
        guard var timer = store.timer, !timer.isRunning else { return }
        timer.resume(now: Date())
        store.update(timer)
        play(.toggleOn)
        let left = PomodoroAnnouncement.minutes(timer.minutesLeft(now: Date()))
        core.showMessage("Pomodoro resumed · \(left) left")
        began()
    }

    func skip() {
        guard var timer = store.timer else { return }
        timer.skip(now: Date(), durations: durations)
        store.update(timer)
        if timer.isRunning { playWindUp(minutes: minutes(of: timer.phase), after: nil) }
        core.showMessage(timer.phase == .rest ? "Skipped to the break" : "Skipped to work")
        if timer.isRunning { began() } else { halted() }
    }

    func stop() {
        guard store.timer != nil else { return }
        store.update(nil)
        play(.toggleOff)
        core.showMessage("Pomodoro stopped")
        halted()
        applyPresence()
    }

    /// Re-read when a length or the notification switch changes, so the pending banner matches.
    func applySettings() {
        announceNext()
    }

    private var durations: PomodoroDurations { settings.pomodoroDurations }

    private func minutes(of phase: PomodoroPhase) -> Int {
        phase == .work ? durations.workMinutes : durations.restMinutes
    }

    private func began() {
        applyPresence()
        announceNext()
        runPump()
    }

    private func halted() {
        pump?.cancel()
        windUp?.cancel()
        sounds.stopWindUp()
        cancelAnnouncement()
        now = Date()
    }

    /// Pause or Resume stays listed while stopped: it starts a cycle, so a chord bound to it works.
    private func applyPresence() {
        appIndex.setCommandsVisible([.startPomodoro], store.timer == nil)
        appIndex.setCommandsVisible(Self.runningCommands, store.timer != nil)
    }

    /// The next phase change is handed to the system ahead of time, so it lands even mid-sleep.
    private func announceNext() {
        cancelAnnouncement()
        guard settings.pomodoroNotificationsEnabled, let timer = store.timer,
            let endsAt = timer.endsAt
        else { return }
        let next = timer.phase.next
        let until = (endsAt + durations.seconds(of: next)).formatted(date: .omitted, time: .shortened)
        let announcement = PomodoroAnnouncement.entering(next, durations: durations, until: until)
        announcing = Task { [notifications] in await notifications.schedule(announcement, at: endsAt) }
    }

    private func cancelAnnouncement() {
        announcing?.cancel()
        notifications.cancel()
    }

    private func runPump() {
        pump?.cancel()
        pump = Task { [weak self] in
            while let wake = self?.tick() {
                try? await Task.sleep(for: .seconds(max(wake.timeIntervalSinceNow, 0)))
                if Task.isCancelled { return }
            }
        }
    }

    /// Rolls the phase over when it ends; answers when the minute count next changes.
    private func tick() -> Date? {
        let date = Date()
        guard var timer = store.timer, timer.isRunning else { return nil }
        if let phase = timer.advance(now: date, durations: durations) {
            store.update(timer)
            play(.ding)
            playWindUp(minutes: minutes(of: phase), after: Self.windUpDelay)
            announceNext()
        }
        now = date
        guard let endsAt = timer.endsAt else { return nil }
        let toBoundary = endsAt.timeIntervalSince(date).truncatingRemainder(dividingBy: 60)
        // A hair past the boundary, so the rounded-up count has already moved when it wakes.
        return date + toBoundary + 0.05
    }

    private func play(_ cue: PomodoroSoundRunner.Cue) {
        guard settings.pomodoroSoundsEnabled else { return }
        sounds.play(cue)
    }

    private func playWindUp(minutes: Int, after delay: Duration?) {
        windUp?.cancel()
        guard settings.pomodoroSoundsEnabled else { return }
        windUp = Task { [weak self] in
            if let delay { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled, let self, settings.pomodoroSoundsEnabled else { return }
            sounds.windUp(minutes: minutes)
        }
    }
}
