import Foundation

/// Toggle Low Power Mode: flips the battery's Energy Mode between Automatic and Low Power.
@MainActor
final class PowerModeCoordinator {
    private let paletteCoordinator: PaletteCoordinator
    /// The pill and the approval dialog, so both stay owned by `AppCore`.
    private unowned let core: AppCore
    private let helper = PowerModeHelperClient()
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
            await set(current.toggled)
        }
    }

    private func set(_ target: PowerMode) async {
        switch helper.prepare() {
        case .ready:
            report(await helper.setBattery(target) ? .changed : .failed, target)
        case .needsApproval:
            await askForApproval()
        case .unavailable:
            // A build the helper cannot run from still works, behind the administrator prompt.
            report(await Task.detached { PowerModeRunner.setBattery(target) }.value, target)
        }
    }

    private func report(_ outcome: PowerModeRunner.Outcome, _ target: PowerMode) {
        switch outcome {
        case .changed: core.showMessage("\(target.title) on battery")
        case .cancelled: break
        case .failed: core.showMessage("Couldn't change the Energy Mode", tone: .danger)
        }
    }

    private func askForApproval() async {
        let open = await core.confirm(
            title: "Allow Tinycast to Change the Energy Mode",
            message: "Switching it needs a small helper that runs as root. Turn Tinycast on under "
                + "Allow in the Background, then toggle again.",
            symbol: "battery.50percent", confirmTitle: "Open Login Items", tone: .neutral,
            confirmRole: .standard)
        if open { helper.openApproval() }
    }
}
