import SwiftUI

/// Listening Ports: every TCP port the reader's processes listen on, and who holds it.
struct PortsScreen: PaletteScreen {
    struct Row: Identifiable {
        let port: ListeningPort
        let bundlePath: String?
        var id: String { port.id }
    }

    let session: ProcessSession
    let core: AppCore
    let vm: PaletteState

    private var coordinator: ProcessCoordinator { core.processCoordinator }

    var rows: [Row] {
        let bundles = Dictionary(
            session.processes.compactMap { process in process.bundlePath.map { (process.pid, $0) } },
            uniquingKeysWith: { first, _ in first })
        return ProcessQuery.filter(session.ports, query: vm.query).map {
            Row(port: $0, bundlePath: bundles[$0.pid])
        }
    }

    var primaryActionTitle: String { "Quit Process" }

    private func port(at selection: Int) -> ListeningPort? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection].port : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let port = port(at: selection) else { return nil }
        return PopoverMenuContent(
            header: ":\(port.port) · \(port.command)",
            items: [
                PopoverMenuItem(title: "Quit Process", systemImage: "xmark.circle", shortcut: "↵") {
                    quit(port, force: false)
                },
                PopoverMenuItem(
                    title: "Force Quit Process", systemImage: "xmark.octagon", shortcut: "⌘↵",
                    isDestructive: true
                ) { quit(port, force: true) },
                PopoverMenuItem(
                    title: "Open in Browser", systemImage: "globe", startsSection: true
                ) { coordinator.openInBrowser(port) },
                PopoverMenuItem(title: "Copy Port", systemImage: "doc.on.doc") {
                    coordinator.copy(String(port.port))
                },
                PopoverMenuItem(title: "Copy PID", systemImage: "doc.on.doc") {
                    coordinator.copy(String(port.pid))
                },
                PopoverMenuItem(
                    title: "Reload", systemImage: "arrow.clockwise", startsSection: true,
                    shortcut: "⌘R"
                ) { coordinator.load() }
            ])
    }

    private func quit(_ port: ListeningPort, force: Bool) {
        coordinator.quit(pid: port.pid, name: port.command, force: force)
    }

    func activate(at selection: Int) {
        guard let port = port(at: selection) else { return }
        quit(port, force: false)
    }

    func secondary(at selection: Int) -> Bool {
        guard let port = port(at: selection) else { return false }
        quit(port, force: true)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard shortcut == .restart else { return false }
        coordinator.load()
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        guard !rows.isEmpty else {
            let text = session.isLoadingPorts ? "Reading ports…" : "No listening ports found"
            return AnyView(EmptyResults(text: text))
        }
        return AnyView(
            PaletteResultList(
                sections: [PaletteResultSection(title: nil, items: rows)],
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll, onActivate: { quit($0.port, force: false) }
            ) { row, selected in
                PaletteResultRow(
                    title: ":\(row.port.port)",
                    subtitle: "\(row.port.command) · PID \(row.port.pid)", selected: selected
                ) {
                    ProcessIcon(bundlePath: row.bundlePath)
                } accessory: {
                    Text(row.port.address == "*" ? "All interfaces" : row.port.address)
                }
            })
    }
}
