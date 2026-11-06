import SwiftUI

/// Listening Ports: every TCP port on the Mac and who holds it; only the reader's own can be quit.
struct PortsScreen: PaletteScreen {
    struct Row: Identifiable {
        let port: ListeningPort
        var id: String { port.id }
    }

    let session: ProcessSession
    let core: AppCore
    let vm: PaletteState

    private var coordinator: ProcessCoordinator { core.processCoordinator }

    var rows: [Row] {
        ProcessQuery.filter(session.ports, query: vm.query).map(Row.init)
    }

    var primaryActionTitle: String { "Quit Process" }

    private func port(at selection: Int) -> ListeningPort? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection].port : nil
    }

    func isPrimaryActionEnabled(at selection: Int) -> Bool {
        port(at: selection)?.identity != nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let port = port(at: selection) else { return nil }
        var items: [PopoverMenuItem] = []
        if let identity = port.identity {
            items += [
                PopoverMenuItem(title: "Quit Process", systemImage: "xmark.circle", shortcut: "↵") {
                    coordinator.quit(identity, name: port.name, force: false)
                },
                PopoverMenuItem(
                    title: "Force Quit Process", systemImage: "xmark.octagon", shortcut: "⌘↵",
                    isDestructive: true
                ) { coordinator.quit(identity, name: port.name, force: true) }
            ]
        }
        items += [
            PopoverMenuItem(
                title: "Open in Browser", systemImage: "globe", startsSection: !items.isEmpty
            ) { coordinator.openInBrowser(port) },
            PopoverMenuItem(title: "Copy Port", systemImage: "doc.on.doc") {
                coordinator.copy(String(port.port))
            },
            PopoverMenuItem(title: "Copy PID", systemImage: "doc.on.doc") {
                coordinator.copy(String(port.pid))
            }
        ]
        if let path = port.path {
            items.append(
                PopoverMenuItem(title: "Show in Finder", systemImage: "folder") {
                    coordinator.showInFinder(path: port.bundlePath ?? path)
                })
        }
        items.append(
            PopoverMenuItem(
                title: "Reload", systemImage: "arrow.clockwise", startsSection: true, shortcut: "⌘R"
            ) { coordinator.reload() })
        return PopoverMenuContent(header: ":\(port.port) – \(port.name)", items: items)
    }

    private func quit(_ port: ListeningPort, force: Bool) {
        guard let identity = port.identity else {
            coordinator.explainUnreachable(port)
            return
        }
        coordinator.quit(identity, name: port.name, force: force)
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
        coordinator.reload()
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            ProcessListHost(
                session: session, vm: vm, rowIDs: rows.map(\.id),
                content: list(rows, selection: selection, scroll: scroll)))
    }

    private func list(_ rows: [Row], selection: Int, scroll: ScrollIntent) -> AnyView {
        guard !rows.isEmpty else {
            let text = session.hasSwept ? "No listening ports found" : "Reading ports…"
            return AnyView(EmptyResults(text: text))
        }
        return AnyView(
            PaletteResultList(
                sections: [PaletteResultSection(title: nil, items: rows)],
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll, onActivate: { quit($0.port, force: false) }
            ) { row, selected in
                PaletteResultRow(
                    title: ":\(row.port.port)", subtitle: Self.subtitle(row.port), selected: selected
                ) {
                    ProcessIcon(bundlePath: row.port.bundlePath)
                } accessory: {
                    Text(row.port.address == "*" ? "All interfaces" : row.port.address)
                }
            })
    }

    private static func subtitle(_ port: ListeningPort) -> String {
        let holder = "\(port.name) – PID \(port.pid)"
        switch port.holder {
        case .reader: return holder
        case .otherUser(let owner): return "\(holder) – \(owner)"
        case .unknown: return "\(holder) – exited"
        }
    }
}
