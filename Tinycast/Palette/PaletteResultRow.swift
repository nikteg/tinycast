import SwiftUI

/// A plain palette row: a glyph, a title and its detail, trailing accessories, and the fill.
struct PaletteResultRow<Leading: View, Accessory: View>: View {
    @Environment(\.metrics) private var metrics
    let title: String
    let subtitle: String?
    let selected: Bool
    let leading: Leading
    let accessory: Accessory
    @State private var hovered = false

    init(
        title: String, subtitle: String? = nil, selected: Bool,
        @ViewBuilder leading: () -> Leading, @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.leading = leading()
        self.accessory = accessory()
    }

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            leading
                .frame(width: metrics.size.resultRowIcon, height: metrics.size.resultRowIcon)
            Text(title)
                .font(metrics.typography.rowTitle)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            if let subtitle {
                Text(subtitle)
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: metrics.spacing.md)
            accessory
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
