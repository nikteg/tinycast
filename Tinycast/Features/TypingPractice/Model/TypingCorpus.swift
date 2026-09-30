import Foundation

struct TypingQuote: Codable, Equatable, Sendable {
    let id: Int
    let text: String
    let source: String

    var words: [String] { text.split(separator: " ").map(String.init) }
}

/// Monkeytype's English words and quotes, as `Scripts/gen-typing-data.js` emits them.
struct TypingCorpus: Sendable {
    let words: [String]
    let quotes: [TypingQuote]

    init(words: [String], quotes: [TypingQuote]) {
        self.words = words
        self.quotes = quotes
    }

    init(wordsData: Data, quotesData: Data) throws {
        let decoder = JSONDecoder()
        self.init(
            words: try decoder.decode([String].self, from: wordsData),
            quotes: try decoder.decode([TypingQuote].self, from: quotesData))
    }

    /// Never the same word twice running, which reads as a stutter rather than a test.
    func randomWords(
        count: Int, after previous: String?, using generator: inout some RandomNumberGenerator
    ) -> [String] {
        guard !words.isEmpty else { return [] }
        var picked: [String] = []
        var last = previous
        while picked.count < count {
            let word = words.randomElement(using: &generator)!
            if word == last, words.count > 1 { continue }
            picked.append(word)
            last = word
        }
        return picked
    }

    /// The quote just typed is skipped whenever its group holds any other.
    func randomQuote(
        _ length: TypingQuoteLength, excluding id: Int?,
        using generator: inout some RandomNumberGenerator
    ) -> TypingQuote? {
        let group = quotes.filter { length.contains($0.text.count) }
        let fresh = group.filter { $0.id != id }
        return (fresh.isEmpty ? group : fresh).randomElement(using: &generator)
    }
}
