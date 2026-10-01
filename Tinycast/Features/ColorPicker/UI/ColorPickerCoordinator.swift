import AppKit

/// Pick Color and its history: sample, copy in any notation, and prune what was kept.
@MainActor
final class ColorPickerCoordinator {
    private let store: ColorHistoryStore
    private let paletteCoordinator: PaletteCoordinator
    /// The pill and the confirmation, so both stay owned by `AppCore`.
    private unowned let core: AppCore
    private let sampler = ColorSampleRunner()

    init(store: ColorHistoryStore, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.store = store
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// The palette steps aside first, so the loupe can reach what it was covering.
    func pickColor() {
        guard !sampler.isSampling else { return }
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette(restoreFocus: true) }
        Task {
            guard let color = await sampler.sample() else { return }
            store.add(color)
            Paster.copyPlainText(color.hex)
            core.showMessage("Copied \(color.hex)")
        }
    }

    func showHistory() {
        paletteCoordinator.togglePalette(mode: .colorHistory)
    }

    func copy(_ color: PickedColor, as format: ColorFormat) {
        paletteCoordinator.hidePalette()
        let text = color.formatted(format)
        Paster.copyPlainText(text)
        core.showMessage("Copied \(text)")
    }

    func delete(_ color: PickedColor) {
        store.remove(color)
    }

    func deleteAll() {
        guard !store.colors.isEmpty else { return }
        Task {
            let confirmed = await core.confirm(
                title: "Delete All Colors?",
                message: "Every picked color is removed from the history.",
                symbol: "eyedropper", confirmTitle: "Delete All")
            if confirmed { store.removeAll() }
        }
    }
}
