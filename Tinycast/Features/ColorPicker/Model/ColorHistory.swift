import Foundation

/// The picked colours kept, newest first, each hex once.
enum ColorHistory {
    static let limit = 100

    /// Picking a colour again moves it to the top rather than listing it twice.
    static func adding(_ color: PickedColor, to colors: [PickedColor]) -> [PickedColor] {
        Array(([color] + colors.filter { $0.hex != color.hex }).prefix(limit))
    }
}
