import Foundation

/// A typed length of time — "10m", "1h30m", "1:30", "2 hours", "25" — and the words around it.
struct DurationPhrase: Equatable, Sendable {
    /// A day: anything longer is almost certainly a typo, not a timer.
    static let longest: TimeInterval = 24 * 60 * 60

    let seconds: TimeInterval
    /// What is left once the duration is read out, as a timer's name.
    let label: String

    /// A bare number means minutes, the way a timer is usually asked for.
    static func parse(_ text: String) -> DurationPhrase? {
        var tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)[...]
        var seconds: TimeInterval = 0
        var found = false
        var words: [String] = []
        while let token = tokens.popFirst() {
            if let read = clockSeconds(token) ?? compactSeconds(token) {
                seconds += read
                found = true
            } else if let number = Double(token), number.isFinite, number >= 0 {
                if let next = tokens.first, let unit = unitSeconds(next) {
                    tokens.removeFirst()
                    seconds += number * unit
                } else {
                    seconds += number * 60
                }
                found = true
            } else {
                words.append(token)
            }
        }
        let rounded = seconds.rounded()
        guard found, rounded > 0, rounded <= longest else { return nil }
        return DurationPhrase(seconds: rounded, label: words.joined(separator: " "))
    }

    private static func unitSeconds(_ word: String) -> TimeInterval? {
        switch word.lowercased() {
        case "h", "hr", "hrs", "hour", "hours": 3600
        case "m", "min", "mins", "minute", "minutes": 60
        case "s", "sec", "secs", "second", "seconds": 1
        default: nil
        }
    }

    /// "4:30" is minutes and seconds, "1:04:30" hours too, as a stopwatch reads.
    private static func clockSeconds(_ token: String) -> TimeInterval? {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count),
            parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) })
        else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count, values.dropFirst().allSatisfy({ $0 < 60 }) else {
            return nil
        }
        return TimeInterval(values.reduce(0) { $0 * 60 + $1 })
    }

    /// "1h30m", "90s", "1.5h" — and "1h30", whose unitless tail is the next unit down.
    private static func compactSeconds(_ token: String) -> TimeInterval? {
        var rest = Substring(token)
        var total: TimeInterval = 0
        var lastUnit: TimeInterval?
        while !rest.isEmpty {
            let digits = rest.prefix { $0.isASCIIDigit || $0 == "." }
            guard let number = Double(digits) else { return nil }
            rest = rest.dropFirst(digits.count)
            let letters = rest.prefix(while: \.isLetter)
            rest = rest.dropFirst(letters.count)
            if letters.isEmpty {
                guard rest.isEmpty, let lastUnit, lastUnit > 1 else { return nil }
                return total + number * lastUnit / 60
            }
            guard let unit = unitSeconds(String(letters)) else { return nil }
            total += number * unit
            lastUnit = unit
        }
        return lastUnit == nil ? nil : total
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
