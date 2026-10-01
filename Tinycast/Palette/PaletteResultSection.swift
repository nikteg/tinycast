import SwiftUI

/// One run of rows under an optional header.
struct PaletteResultSection<Item: Identifiable>: Identifiable where Item.ID == String {
    let title: String?
    let items: [Item]

    var id: String { items.first?.id ?? title ?? "" }
}
