import Foundation

/// The Energy Mode picker in Settings › Battery, by `pmset`'s own numbers.
enum PowerMode: Int, Sendable {
    case automatic = 0
    case low = 1
    case high = 2

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .low: "Low Power"
        case .high: "High Power"
        }
    }

    /// Between Automatic and Low Power; High Power counts as not low.
    var toggled: PowerMode { self == .low ? .automatic : .low }

    /// The battery's mode from `pmset -g custom`; nil on a Mac with no battery section.
    static func battery(pmsetCustom output: String) -> PowerMode? {
        var inBattery = false
        for line in output.split(whereSeparator: \.isNewline) {
            if !line.hasPrefix(" ") {
                inBattery = line.hasPrefix("Battery Power")
                continue
            }
            let fields = line.split(separator: " ")
            guard inBattery, fields.count == 2, fields[0] == "powermode" else { continue }
            return Int(fields[1]).flatMap(PowerMode.init(rawValue:))
        }
        return nil
    }
}
