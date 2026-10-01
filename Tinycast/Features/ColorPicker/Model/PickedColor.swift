import Foundation

/// One colour taken off the screen, in sRGB; its notations are the clipboard's `ColorFormat`.
struct PickedColor: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// 0–255, the precision the eyedropper's notations state anyway.
    let red: Int
    let green: Int
    let blue: Int
    let pickedAt: Date

    init(red: Int, green: Int, blue: Int, pickedAt: Date, id: UUID = UUID()) {
        self.id = id
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
        self.pickedAt = pickedAt
    }

    /// From unit channels, as `NSColor` reports them.
    init(red: Double, green: Double, blue: Double, pickedAt: Date, id: UUID = UUID()) {
        func byte(_ unit: Double) -> Int {
            unit.isFinite ? Int((min(max(unit, 0), 1) * 255).rounded()) : 0
        }
        self.init(red: byte(red), green: byte(green), blue: byte(blue), pickedAt: pickedAt, id: id)
    }

    var value: ColorValue {
        ColorValue(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// A picked colour is always opaque, so the alpha spellings never appear.
    var formats: [ColorFormat] { ColorFormat.offered(for: value) }

    func formatted(_ format: ColorFormat) -> String { format.string(for: value) }

    var hex: String { formatted(.hex) }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        let bare = needle.hasPrefix("#") ? String(needle.dropFirst()) : needle
        return hex.lowercased().contains(bare) || formatted(.rgba).contains(needle)
    }
}
