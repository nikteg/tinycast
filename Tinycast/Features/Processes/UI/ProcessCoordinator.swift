import AppKit

/// Kill Process and Listening Ports: sweep on open, then quit or force-quit what is chosen.
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

    func showProcesses() {
        paletteCoordinator.togglePalette(mode: .processes)
    }

    func showPorts() {
        paletteCoordinator.togglePalette(mode: .ports)
    }

    /// Tinycast leaves itself off the list: quitting it from its own palette is Quit Tinycast.
    func load() {
        session.load(excluding: ProcessInfo.processInfo.processIdentifier)
    }

    /// SIGTERM lets the process clean up; force sends SIGKILL, which it cannot refuse.
    func quit(pid: Int32, name: String, force: Bool) {
        if let failure = ProcessSignalRunner.send(force ? SIGKILL : SIGTERM, to: pid) {
            core.showMessage("Couldn't quit \(name): \(failure)", tone: .danger)
            return
        }
        session.forget(pid)
        core.showMessage(force ? "Force quit \(name)" : "Quit \(name)")
    }

    func copy(_ text: String) {
        paletteCoordinator.hidePalette()
        Paster.copyPlainText(text)
        core.showMessage("Copied \(text)")
    }

    func showInFinder(_ process: RunningProcess) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(URL(fileURLWithPath: process.bundlePath ?? process.path))
    }

    func openInBrowser(_ port: ListeningPort) {
        guard let url = URL(string: "http://localhost:\(port.port)") else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.open(url)
    }
}
