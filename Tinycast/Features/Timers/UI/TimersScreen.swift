import SwiftUI

/// Start Timer: type a length and a name — "10m tea" — or pick one; running timers sit below.
struct TimersScreen: PaletteScreen {
    enum Row: Identifiable {
        case start(DurationPhrase)
        case timer(CountdownTimer)

        var id: String {
            switch self {
            case .start(let phrase): "start:\(phrase.seconds):\(phrase.label)"
            case .timer(let timer): timer.id.uuidString
            }
        }
    }

    let coordinator: TimerCoordinator
    let vm: PaletteState

    private var query: String { vm.query.trimmingCharacters(in: .whitespaces) }

    private var sections: [PaletteResultSection<Row>] {
        let running = coordinator.timers.map(Row.timer)
        let starts: [Row]
        if let phrase = DurationPhrase.parse(query) {
            starts = [.start(phrase)]
        } else if query.isEmpty {
            starts = TimerCoordinator.presets.map {
                .start(DurationPhrase(seconds: TimeInterval($0 * 60), label: ""))
            }
        } else {
            let matching = coordinator.timers.filter { $0.title.localizedCaseInsensitiveContains(query) }
            return matching.isEmpty
                ? [] : [PaletteResultSection(title: "Timers", items: matching.map(Row.timer))]
        }
        let start = PaletteResultSection(title: "Start a Timer", items: starts)
        guard !running.isEmpty else { return [start] }
        let timers = PaletteResultSection(title: "Timers", items: running)
        // Typing a length means starting one, so the new timer leads; idle, the running ones do.
        return query.isEmpty ? [timers, start] : [start, timers]
    }

    var rows: [Row] { sections.flatMap(\.items) }

    var primaryActionTitle: String { "Start Timer" }

    private func row(at selection: Int) -> Row? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func hasActions(at selection: Int) -> Bool {
        if case .timer = row(at: selection) { return true }
        return false
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard case .timer(let timer) = row(at: selection) else { return nil }
        return PopoverMenuContent(
            header: timer.title,
            items: [
                PopoverMenuItem(
                    title: timer.isRunning ? "Pause Timer" : "Resume Timer",
                    systemImage: timer.isRunning ? "pause" : "play", shortcut: "↵"
                ) { coordinator.togglePause(timer.id) },
                PopoverMenuItem(
                    title: "Restart Timer", systemImage: "arrow.counterclockwise", shortcut: "⌘R"
                ) { coordinator.restart(timer.id) },
                PopoverMenuItem(
                    title: "Stop Timer", systemImage: "stop", startsSection: true,
                    shortcut: "⌃X", isDestructive: true
                ) { coordinator.stop(timer.id) },
                PopoverMenuItem(
                    title: "Stop All Timers", systemImage: "stop.circle", shortcut: "⌃⇧X",
                    isDestructive: true
                ) { coordinator.stopAll() }
            ])
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        run(row)
    }

    private func run(_ row: Row) {
        switch row {
        case .start(let phrase): coordinator.startTimer(phrase)
        case .timer(let timer): coordinator.togglePause(timer.id)
        }
    }

    func secondary(at selection: Int) -> Bool { false }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        if shortcut == .deleteAll {
            coordinator.stopAll()
            return true
        }
        guard case .timer(let timer) = row(at: selection) else { return false }
        switch shortcut {
        case .restart: coordinator.restart(timer.id)
        case .delete: coordinator.stop(timer.id)
        default: return false
        }
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let sections = sections
        let rows = sections.flatMap(\.items)
        guard !rows.isEmpty else {
            return AnyView(EmptyResults(text: "Type a length and a name, like 10m tea"))
        }
        return AnyView(
            PaletteResultList(
                sections: sections,
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll, onActivate: run
            ) { row, selected in
                TimerRowView(row: row, now: coordinator.now, selected: selected)
            })
    }
}

private struct TimerRowView: View {
    let row: TimersScreen.Row
    let now: Date
    let selected: Bool

    var body: some View {
        switch row {
        case .start(let phrase):
            PaletteResultRow(
                title: phrase.label.isEmpty ? DurationText.spoken(phrase.seconds) : phrase.label,
                subtitle: phrase.label.isEmpty ? nil : DurationText.spoken(phrase.seconds),
                selected: selected
            ) {
                EntryIconView(source: .symbol("stopwatch"))
            } accessory: {
                EmptyView()
            }
        case .timer(let timer):
            PaletteResultRow(
                title: timer.title,
                subtitle: timer.label.isEmpty ? nil : DurationText.spoken(timer.duration),
                selected: selected
            ) {
                EntryIconView(source: .symbol(timer.isRunning ? "timer" : "pause.circle"))
            } accessory: {
                Text(
                    (timer.isRunning ? "" : "Paused · ")
                        + DurationText.countdown(timer.remaining(now: now))
                )
                .monospacedDigit()
            }
        }
    }
}
