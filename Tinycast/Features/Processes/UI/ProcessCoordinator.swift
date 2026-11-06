import AppKit

/// Kill Process and Listening Ports: a clean sweep on open, then quit or force-quit what is chosen.
@MainActor
final class ProcessCoordinator {
    private let session: ProcessSession
    private let paletteCoordinator: PaletteCoordinator
    /// The pill, so it stays owned by `AppCore`.
    private unowned let core: AppCore

    init(session: ProcessSession, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.session = session
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// Tinycast leaves itself off the list: quitting it from its own palette is Quit Tinycast.
    static var ownPID: Int32 { ProcessInfo.processInfo.processIdentifier }

    func showProcesses() {
        paletteCoordinator.togglePalette(mode: .processes)
    }

    func showPorts() {
        paletteCoordinator.togglePalette(mode: .ports)
    }

    func screenOpening() {
        session.reset()
    }

    func reload() {
        session.reload()
    }

    /// SIGTERM lets the process clean up; force sends SIGKILL, which it cannot refuse.
    func quit(_ process: ProcessIdentity, name: String, force: Bool) {
        switch ProcessSignalRunner.send(force ? SIGKILL : SIGTERM, to: process) {
        case .delivered:
            core.showMessage(force ? "Force quit \(name)" : "Quit \(name)")
        case .exited:
            core.showMessage("\(name) had already quit")
        case .refused(let reason):
            core.showMessage("Couldn't quit \(name): \(reason)", tone: .danger)
            return
        }
        session.forget(process.pid)
        session.sweepSoon()
    }

    /// Another account's listener is shown so the port list is whole, but a signal can't reach it.
    func explainUnreachable(_ port: ListeningPort) {
        switch port.holder {
        case .otherUser(let owner):
            core.showMessage("\(port.name) belongs to \(owner), so Tinycast can't quit it", tone: .danger)
        case .unknown:
            core.showMessage("The process holding :\(port.port) has already quit")
            session.sweepSoon()
        case .reader:
            break
        }
    }

    func copy(_ text: String) {
        paletteCoordinator.hidePalette()
        Paster.copyPlainText(text)
        core.showMessage("Copied \(text)")
    }

    func showInFinder(path: String) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(URL(fileURLWithPath: path))
    }

    func openInBrowser(_ port: ListeningPort) {
        guard let url = URL(string: "http://localhost:\(port.port)") else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.open(url)
    }
}
