import SwiftUI

/// Caffeinate for Duration: a typed length — "45m", "2h" — or one of the usual ones.
struct CaffeinateScreen: PaletteScreen {
    enum Row: Identifiable {
        case decaffeinate
        case lasting(TimeInterval?)

        var id: String {
            switch self {
            case .decaffeinate: "decaffeinate"
            case .lasting(let seconds): "lasting:\(seconds.map { String($0) } ?? "open")"
            }
        }

        var title: String {
            switch self {
            case .decaffeinate: "Decaffeinate"
            case .lasting(let seconds): Caffeination.title(for: seconds)
            }
        }

        var symbol: String {
            switch self {
            case .decaffeinate: "moon.zzz"
            case .lasting(.none): "infinity"
            case .lasting: "hourglass"
            }
        }
    }

    let coordinator: CaffeinateCoordinator
    let vm: PaletteState

    private var query: String { vm.query.trimmingCharacters(in: .whitespaces) }

    var rows: [Row] {
        if let phrase = DurationPhrase.parse(query) { return [.lasting(phrase.seconds)] }
        let all = (coordinator.caffeination == nil ? [] : [Row.decaffeinate])
            + Caffeination.presets.map(Row.lasting)
        guard !query.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var primaryActionTitle: String { "Caffeinate" }

    func hasActions(at selection: Int) -> Bool { false }

    func activate(at selection: Int) {
        let rows = rows
        guard rows.indices.contains(selection) else { return }
        run(rows[selection])
    }

    func secondary(at selection: Int) -> Bool { false }

    private func run(_ row: Row) {
        switch row {
        case .decaffeinate: coordinator.decaffeinate()
        case .lasting(let seconds): coordinator.caffeinate(for: seconds)
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        guard !rows.isEmpty else {
            return AnyView(EmptyResults(text: "Type a length, like 45m or 1h30m"))
        }
        return AnyView(
            PaletteResultList(
                sections: [PaletteResultSection(title: coordinator.status, items: rows)],
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll, onActivate: run
            ) { row, selected in
                PaletteResultRow(title: row.title, selected: selected) {
                    EntryIconView(source: .symbol(row.symbol))
                } accessory: {
                    EmptyView()
                }
            })
    }
}
