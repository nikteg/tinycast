import AppKit

/// The fork's updates: it cannot install one, so it says what to run and where.
@MainActor
final class ForkUpdateCoordinator {
    /// How many commit subjects the prompt lists before summarising the rest.
    private static let shownSubjects = 6

    private let checker = ForkUpdateChecker()
    /// Dialogs, the HUD and activity reads only — never for state this type owns.
    private unowned let core: AppCore
    private var isPresenting = false

    init(core: AppCore) {
        self.core = core
    }

    func start() {
        guard ReleaseChannel(bundleID: Bundle.main.bundleIdentifier) == .fork else { return }
        checker.onUpdateAvailable = { [weak self] update in self?.presentIfAllowed(update) ?? true }
        checker.start()
    }

    /// Check for Updates on the fork: always asks GitHub, and always answers.
    func checkForUpdates() {
        Task {
            switch await checker.check() {
            case .available(let update):
                await present(update)
            case .upToDate:
                core.showMessage("Tinycast Fork is up to date")
            case .unpublished:
                await core.showNotice(
                    title: "This build is not on GitHub",
                    message: "It was built from a commit \(ForkFeed.repository) does not have yet, "
                        + "so there is nothing to compare it with. Push it, or pull and reinstall.",
                    symbol: "questionmark.circle", tone: .neutral)
            case .unknownBuild:
                await core.showNotice(
                    title: "This build cannot check for updates",
                    message: "It does not record the commit it was built from. "
                        + "Reinstall it from its clone with `mise run install`.",
                    symbol: "questionmark.circle", tone: .neutral)
            case .failed:
                core.showMessage("Tinycast could not reach GitHub", tone: .danger)
            }
        }
    }

    /// The automatic path: `false` answers that it withheld the prompt, so the checker re-offers it.
    private func presentIfAllowed(_ update: ForkUpdate) -> Bool {
        guard !isPresenting else { return true }
        guard core.canInterruptUser else { return false }
        Task { await present(update) }
        return true
    }

    private func present(_ update: ForkUpdate) async {
        guard !isPresenting else { return }
        isPresenting = true
        defer { isPresenting = false }
        let command = ForkFeed.command(sourcePath: checker.sourcePath)
        var lines = update.subjects.prefix(Self.shownSubjects).map { "• \($0)" }
        if update.subjects.count > Self.shownSubjects {
            lines.append("…and \(update.subjects.count - Self.shownSubjects) more")
        }
        let choice = await core.choose(
            title: update.aheadBy == 1
                ? "Tinycast Fork has 1 new commit" : "Tinycast Fork has \(update.aheadBy) new commits",
            message: lines.joined(separator: "\n") + "\n\nTo update, run this in Terminal:\n\(command)",
            symbol: "arrow.down.circle",
            options: [
                DialogAction(title: "Copy Update Command"),
                DialogAction(title: "Open on GitHub"),
                DialogAction(title: "Later", role: .cancel)
            ],
            defaultIndex: 0)
        switch choice {
        case 0:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            core.showMessage("Update command copied")
        case 1:
            NSWorkspace.shared.open(update.compareURL)
        default:
            checker.skip(update)
        }
    }
}
