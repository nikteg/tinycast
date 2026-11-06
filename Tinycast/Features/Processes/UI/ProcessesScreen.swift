import SwiftUI

/// Kill Process: the reader's own processes, busiest first; a name, pid or port narrows them.
struct ProcessesScreen: PaletteScreen {
    struct Row: Identifiable {
        let process: RunningProcess
        let ports: [Int]
        var id: String { process.id }
    }

    let session: ProcessSession
    let core: AppCore
    let vm: PaletteState

    private var coordinator: ProcessCoordinator { core.processCoordinator }

    var rows: [Row] {
        let ports = ProcessQuery.portsByProcess(session.ports)
        return ProcessQuery.filter(session.processes, ports: ports, query: vm.query).map {
            Row(process: $0, ports: ports[$0.pid] ?? [])
        }
    }

    var primaryActionTitle: String { "Quit Process" }

    private func process(at selection: Int) -> RunningProcess? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection].process : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let process = process(at: selection) else { return nil }
        return PopoverMenuContent(
            header: "\(process.name) – PID \(process.pid)",
            items: [
                PopoverMenuItem(title: "Quit Process", systemImage: "xmark.circle", shortcut: "↵") {
                    quit(process, force: false)
                },
                PopoverMenuItem(
                    title: "Force Quit Process", systemImage: "xmark.octagon", shortcut: "⌘↵",
                    isDestructive: true
                ) { quit(process, force: true) },
                PopoverMenuItem(
                    title: "Copy PID", systemImage: "doc.on.doc", startsSection: true
                ) { coordinator.copy(String(process.pid)) },
                PopoverMenuItem(title: "Copy Path", systemImage: "doc.on.doc") {
                    coordinator.copy(process.path)
                },
                PopoverMenuItem(title: "Show in Finder", systemImage: "folder") {
                    coordinator.showInFinder(path: process.bundlePath ?? process.path)
                },
                PopoverMenuItem(
                    title: "Reload", systemImage: "arrow.clockwise", startsSection: true,
                    shortcut: "⌘R"
                ) { coordinator.reload() }
            ])
    }

    private func quit(_ process: RunningProcess, force: Bool) {
        coordinator.quit(process.identity, name: process.name, force: force)
    }

    func activate(at selection: Int) {
        guard let process = process(at: selection) else { return }
        quit(process, force: false)
    }

    func secondary(at selection: Int) -> Bool {
        guard let process = process(at: selection) else { return false }
        quit(process, force: true)
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
            let text = session.hasSwept ? "No matching processes" : "Reading processes…"
            return AnyView(EmptyResults(text: text))
        }
        return AnyView(
            PaletteResultList(
                sections: [PaletteResultSection(title: nil, items: rows)],
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll, onActivate: { quit($0.process, force: false) }
            ) { row, selected in
                PaletteResultRow(
                    title: row.process.name, subtitle: Self.subtitle(row), selected: selected
                ) {
                    ProcessIcon(bundlePath: row.process.bundlePath)
                } accessory: {
                    ProcessUsage(process: row.process)
                }
            })
    }

    private static func subtitle(_ row: Row) -> String {
        let ports = row.ports.map { ":\($0)" }.joined(separator: ", ")
        return ports.isEmpty ? "PID \(row.process.pid)" : "PID \(row.process.pid) – \(ports)"
    }
}

/// CPU and memory side by side, in tabular figures so a live refresh doesn't jiggle the column.
private struct ProcessUsage: View {
    @Environment(\.metrics) private var metrics
    let process: RunningProcess

    var body: some View {
        HStack(spacing: metrics.spacing.md) {
            Text("\(process.cpu.formatted(.number.precision(.fractionLength(1))))%")
            Text(ByteCountFormatter.string(fromByteCount: process.memoryBytes, countStyle: .memory))
        }
        .monospacedDigit()
    }
}
