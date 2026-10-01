import Foundation

/// Runs any number of named countdowns: the second pump, the chime, the banners, the presence.
@MainActor
@Observable
final class TimerCoordinator {
    /// Offered before anything is typed, in minutes.
    static let presets: [Int] = [1, 3, 5, 10, 15, 25, 30, 45, 60]

    /// Advanced by the pump while a timer runs, so every countdown on screen reads one clock.
    private(set) var now = Date()
    /// Set by dragging the menu-bar countdown out; the next timer started brings it back.
    var isMenuBarDismissed = false

    @ObservationIgnored private let store: TimerStore
    @ObservationIgnored private let appIndex: AppIndex
    @ObservationIgnored private let paletteCoordinator: PaletteCoordinator
    /// The pill, so it stays owned by `AppCore`.
    @ObservationIgnored private unowned let core: AppCore
    @ObservationIgnored private let alerts = TimerAlertRunner()
    @ObservationIgnored private var pump: Task<Void, Never>?

    init(
        store: TimerStore, appIndex: AppIndex, paletteCoordinator: PaletteCoordinator,
        core: AppCore
    ) {
        self.store = store
        self.appIndex = appIndex
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// Soonest to ring first.
    var timers: [CountdownTimer] { CountdownTimer.ordered(store.timers, now: now) }

    /// A timer that rang while Tinycast was quit already had its banner; it just goes.
    func start() {
        let date = Date()
        store.update(store.timers.filter { !$0.hasEnded(now: date) })
        now = date
        applyPresence()
        runPump()
    }

    func show() {
        paletteCoordinator.togglePalette(mode: .timers)
    }

    func startTimer(_ phrase: DurationPhrase) {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette() }
        let timer = CountdownTimer.start(phrase, now: Date())
        store.update(store.timers + [timer])
        isMenuBarDismissed = false
        schedule(timer)
        core.showMessage("Timer started · \(DurationText.spoken(timer.duration))")
        changed()
    }

    func togglePause(_ id: UUID) {
        modify(id) { timer, date in
            if timer.isRunning { timer.pause(now: date) } else { timer.resume(now: date) }
        }
    }

    func restart(_ id: UUID) {
        modify(id) { timer, date in timer.restart(now: date) }
    }

    func stop(_ id: UUID) {
        alerts.cancel(id)
        store.update(store.timers.filter { $0.id != id })
        changed()
    }

    func stopAll() {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette() }
        guard !store.timers.isEmpty else { return }
        for timer in store.timers { alerts.cancel(timer.id) }
        store.update([])
        core.showMessage("Timers stopped")
        changed()
    }

    private func modify(_ id: UUID, _ change: (inout CountdownTimer, Date) -> Void) {
        let date = Date()
        var timers = store.timers
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        change(&timers[index], date)
        store.update(timers)
        let timer = timers[index]
        if timer.isRunning { schedule(timer) } else { alerts.cancel(id) }
        changed()
    }

    private func schedule(_ timer: CountdownTimer) {
        Task { [alerts] in await alerts.schedule(timer) }
    }

    private func changed() {
        now = Date()
        applyPresence()
        runPump()
    }

    private func applyPresence() {
        appIndex.setCommandsVisible([.stopAllTimers], !store.timers.isEmpty)
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

    /// Rings what has ended; answers when the soonest countdown next changes its second.
    private func tick() -> Date? {
        let date = Date()
        let ended = store.timers.filter { $0.hasEnded(now: date) }
        if !ended.isEmpty {
            store.update(store.timers.filter { !$0.hasEnded(now: date) })
            alerts.chimeNow()
            for timer in ended { core.showMessage("Time's up · \(timer.title)") }
            applyPresence()
        }
        now = date
        guard let soonest = store.timers.compactMap(\.endsAt).min() else { return nil }
        let fraction = soonest.timeIntervalSince(date).truncatingRemainder(dividingBy: 1)
        // A hair past the boundary, so the rounded-up count has already moved when it wakes.
        return date + fraction + 0.02
    }
}
