import Foundation

/// A countdown over random common words, or one quote typed to its end.
enum TypingTestMode: String, Codable, CaseIterable, Sendable {
    case time
    case quote

    var title: String { rawValue }
}

enum TypingDuration: Int, Codable, CaseIterable, Sendable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    case twoMinutes = 120

    var seconds: Int { rawValue }
    var title: String { String(rawValue) }
}

/// Monkeytype's quote groups, by character count; `all` draws from every group.
enum TypingQuoteLength: String, Codable, CaseIterable, Sendable {
    case all
    case short
    case medium
    case long
    case thicc

    var title: String { rawValue }

    func contains(_ characterCount: Int) -> Bool {
        switch self {
        case .all: true
        case .short: characterCount <= 100
        case .medium: (101...300).contains(characterCount)
        case .long: (301...600).contains(characterCount)
        case .thicc: characterCount > 600
        }
    }
}

struct TypingTestConfig: Codable, Hashable, Sendable {
    var mode: TypingTestMode = .time
    var duration: TypingDuration = .thirty
    var quoteLength: TypingQuoteLength = .all

    /// The only fields that decide the test, so a personal best is never compared across kinds.
    var title: String {
        switch mode {
        case .time: "time \(duration.title)"
        case .quote: "quote \(quoteLength.title)"
        }
    }
}
