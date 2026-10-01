import SwiftUI

/// The scrolling scaffold a plain palette list shares: sections, selection following, clicks.
struct PaletteResultList<Item: Identifiable, Row: View>: View where Item.ID == String {
    @Environment(\.metrics) private var metrics
    let sections: [PaletteResultSection<Item>]
    let selectedID: String?
    let scroll: ScrollIntent
    let onActivate: (Item) -> Void
    @ViewBuilder let row: (Item, Bool) -> Row

    private var firstRowSelected: Bool {
        selectedID != nil && selectedID == sections.first?.items.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        if let title = section.title {
                            SectionHeader(title: title, isFirst: index == 0)
                        }
                        ForEach(section.items) { item in
                            row(item, item.id == selectedID)
                                .selectionFrame(item.id == selectedID)
                                .contentShape(Rectangle())
                                .onTapGesture { onActivate(item) }
                        }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: firstRowSelected, proxy: proxy)
        }
    }
}
