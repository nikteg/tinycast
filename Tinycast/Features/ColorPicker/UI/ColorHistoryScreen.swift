import SwiftUI

/// Color History: every picked colour, newest first, copied in whichever notation is wanted.
struct ColorHistoryScreen: PaletteScreen {
    struct Row: Identifiable {
        let color: PickedColor
        var id: String { color.id.uuidString }
    }

    let store: ColorHistoryStore
    let core: AppCore
    let vm: PaletteState

    private var coordinator: ColorPickerCoordinator { core.colorPickerCoordinator }

    var rows: [Row] {
        store.colors.filter { $0.matches(vm.query) }.map(Row.init)
    }

    var primaryActionTitle: String { "Copy Hex" }

    private func color(at selection: Int) -> PickedColor? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection].color : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let color = color(at: selection) else { return nil }
        let copies = color.formats.enumerated().map { index, format in
            PopoverMenuItem(
                title: "Copy \(format.title)", icon: .symbol("doc.on.doc"),
                shortcut: index == 0 ? "↵" : index == 1 ? "⌘↵" : nil,
                detail: color.formatted(format)
            ) { coordinator.copy(color, as: format) }
        }
        return PopoverMenuContent(
            header: color.hex,
            items: copies + [
                PopoverMenuItem(
                    title: "Pick Color", systemImage: "eyedropper", startsSection: true,
                    shortcut: "⌘N"
                ) { coordinator.pickColor() },
                PopoverMenuItem(
                    title: "Delete Color", systemImage: "trash", startsSection: true,
                    shortcut: "⌃X", isDestructive: true
                ) { coordinator.delete(color) },
                PopoverMenuItem(
                    title: "Delete All Colors", systemImage: "trash", shortcut: "⌃⇧X",
                    isDestructive: true
                ) { coordinator.deleteAll() }
            ])
    }

    func activate(at selection: Int) {
        guard let color = color(at: selection) else { return }
        coordinator.copy(color, as: .hex)
    }

    func secondary(at selection: Int) -> Bool {
        guard let color = color(at: selection) else { return false }
        coordinator.copy(color, as: .rgba)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        switch shortcut {
        case .newItem:
            coordinator.pickColor()
        case .delete:
            guard let color = color(at: selection) else { return false }
            coordinator.delete(color)
        case .deleteAll:
            coordinator.deleteAll()
        default:
            return false
        }
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        guard !rows.isEmpty else {
            let text = store.colors.isEmpty ? "No colors yet · ⌘N picks one" : "No matching colors"
            return AnyView(EmptyResults(text: text))
        }
        return AnyView(
            PaletteResultList(
                sections: [PaletteResultSection(title: nil, items: rows)],
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll,
                onActivate: { coordinator.copy($0.color, as: .hex) }
            ) { row, selected in
                PaletteResultRow(
                    title: row.color.hex, subtitle: row.color.formatted(.rgba), selected: selected
                ) {
                    ColorSwatch(color: row.color.value)
                } accessory: {
                    Text(row.color.pickedAt, format: .relative(presentation: .named))
                }
            })
    }
}
