import AppKit
import SwiftUI

/// Typing Practice's action surface: open the screen, copy the score card, clear the history.
@MainActor
final class TypingPracticeCoordinator {
    let session: TypingPracticeSession
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(session: TypingPracticeSession, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.session = session
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    func show() {
        paletteCoordinator.togglePalette(mode: .typingPractice)
    }

    /// False with no result to copy, which leaves ⌘C to whatever else wants it.
    @discardableResult
    func copyScoreCard() -> Bool {
        guard let result = session.result else { return false }
        let card = TypingScoreCard(
            result: result, isNewBest: session.isNewBest,
            personalBest: session.store.history.personalBest(for: result.config))
        let renderer = ImageRenderer(content: card)
        renderer.scale = Theme.Typing.scoreCardScale
        var image: NSImage?
        // The card's ink resolves per appearance, which a renderer reads from the drawing context.
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance { image = renderer.nsImage }
        guard let image else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        core.showMessage("Copied score card")
        return true
    }

    func clearHistory() {
        Task {
            let confirmed = await core.confirm(
                title: "Clear typing history?",
                message: "Every past result and personal best is deleted.",
                symbol: "keyboard", confirmTitle: "Clear History")
            guard confirmed else { return }
            session.clearHistory()
        }
    }
}
