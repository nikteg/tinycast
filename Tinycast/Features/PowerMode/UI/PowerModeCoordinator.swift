import Foundation

/// Toggle Low Power Mode: flips the battery's Energy Mode between Automatic and Low Power.
@MainActor
final class PowerModeCoordinator {
    private let paletteCoordinator: PaletteCoordinator
    /// The pill, so it stays owned by `AppCore`.
    private unowned let core: AppCore
    private var isSwitching = false

    init(paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// Read fresh every time: Settings, Control Center or `pmset` may have moved it since.
    func toggleLowPowerMode() {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette() }
        guard !isSwitching else { return }
        isSwitching = true
        Task {
            defer { isSwitching = false }
            guard let current = await Task.detached(operation: PowerModeRunner.batteryMode).value
            else {
                core.showMessage("This Mac has no battery Energy Mode", tone: .danger)
                return
            }
            let target = current.toggled
            switch await Task.detached(operation: { PowerModeRunner.setBattery(target) }).value {
            case .changed: core.showMessage("\(target.title) on battery")
            case .cancelled: break
            case .failed: core.showMessage("Couldn't change the Energy Mode", tone: .danger)
            }
        }
    }
}
