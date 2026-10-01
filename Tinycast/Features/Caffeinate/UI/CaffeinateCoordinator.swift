import Foundation

/// Keeps the Mac awake on request, until turned off or for a while, like Raycast's Coffee.
@MainActor
@Observable
final class CaffeinateCoordinator {
    /// Nil while the Mac may sleep as usual.
    private(set) var caffeination: Caffeination?
    /// Set by dragging the menu-bar cup out; the next caffeination brings it back.
    var isMenuBarDismissed = false

    @ObservationIgnored private let paletteCoordinator: PaletteCoordinator
    /// The pill, so it stays owned by `AppCore`.
    @ObservationIgnored private unowned let core: AppCore
    @ObservationIgnored private let assertion = SleepAssertion()
    @ObservationIgnored private var expiry: Task<Void, Never>?

    init(paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    var status: String? {
        caffeination?.status(
            until: caffeination?.endsAt?.formatted(date: .omitted, time: .shortened))
    }

    func toggle() {
        if caffeination == nil { caffeinate(for: nil) } else { decaffeinate() }
    }

    func showDurations() {
        paletteCoordinator.togglePalette(mode: .caffeinate)
    }

    /// A new length replaces the running one rather than adding to it.
    func caffeinate(for seconds: TimeInterval?) {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette() }
        guard assertion.hold(reason: "Caffeinated from Tinycast") else {
            core.showMessage("Couldn't keep the Mac awake", tone: .danger)
            return
        }
        let next = Caffeination.lasting(seconds, now: Date())
        caffeination = next
        isMenuBarDismissed = false
        scheduleExpiry(next)
        if let status { core.showMessage(status) }
    }

    func decaffeinate() {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette() }
        guard caffeination != nil else { return }
        end()
        core.showMessage("Decaffeinated")
    }

    private func end() {
        expiry?.cancel()
        assertion.release()
        caffeination = nil
    }

    /// The continuous clock counts a lid-closed sleep, so the end lands on the wall clock.
    private func scheduleExpiry(_ caffeination: Caffeination) {
        expiry?.cancel()
        guard let endsAt = caffeination.endsAt else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, endsAt.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }
}
