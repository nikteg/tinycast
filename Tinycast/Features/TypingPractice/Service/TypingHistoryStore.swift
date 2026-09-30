import Foundation

/// Past results and the chosen test, kept on disk so progress survives a relaunch.
@MainActor
@Observable
final class TypingHistoryStore {
    private(set) var history: TypingHistory

    @ObservationIgnored private let fileURL: URL

    init(
        fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("typing-practice.json")
    ) {
        self.fileURL = fileURL
        history =
            (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode(TypingHistory.self, from: $0) } ?? TypingHistory()
    }

    var config: TypingTestConfig {
        get { history.config }
        set {
            guard newValue != history.config else { return }
            history.config = newValue
            save()
        }
    }

    /// True when the result is a new personal best.
    func add(_ result: TypingResult) -> Bool {
        let isBest = history.add(result.record)
        save()
        return isBest
    }

    func clear() {
        history.clear()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension TypingCorpus {
    /// Two megabytes of quotes: decoded off the main actor, once, on the first test.
    nonisolated static func loadBundled() async -> TypingCorpus? {
        await Task.detached(priority: .userInitiated) {
            guard
                let words = Bundle.main.url(
                    forResource: "TypingWords.generated", withExtension: "json"),
                let quotes = Bundle.main.url(
                    forResource: "TypingQuotes.generated", withExtension: "json"),
                let wordsData = try? Data(contentsOf: words),
                let quotesData = try? Data(contentsOf: quotes)
            else { return nil }
            return try? TypingCorpus(wordsData: wordsData, quotesData: quotesData)
        }.value
    }
}
