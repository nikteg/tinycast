import Foundation

/// The test on screen: what is typed, the clock that ends it, and the result it leaves.
@MainActor
@Observable
final class TypingPracticeSession {
    /// A time test keeps this many words ahead of the caret, so the next lines are always there.
    private static let wordsAhead = 60
    private static let tickInterval: Duration = .milliseconds(100)

    let store: TypingHistoryStore
    private(set) var test: TypingTest?
    private(set) var result: TypingResult?
    private(set) var isNewBest = false
    /// What the hidden field shows: `TypingFieldEdit`'s sentinel, then the word in progress.
    private(set) var fieldText = String(TypingFieldEdit.sentinel)
    /// Advanced by the tick, so the countdown and live speed move between keys.
    private(set) var now: TimeInterval
    private(set) var isLoading = false

    @ObservationIgnored private var corpus: TypingCorpus?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let clock: () -> TimeInterval

    init(
        store: TypingHistoryStore,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.store = store
        self.clock = clock
        now = clock()
    }

    var config: TypingTestConfig { store.config }
    var isRunning: Bool { test.map { $0.isStarted && !$0.isFinished } ?? false }
    var isFinished: Bool { result != nil }

    /// Seconds left in a time test, or nil for a quote.
    var secondsLeft: Int? {
        guard let test, test.config.mode == .time else { return nil }
        let left = TimeInterval(test.config.duration.seconds) - test.elapsed(at: now)
        return max(0, Int(left.rounded(.up)))
    }

    var liveWPM: Double {
        guard let test, test.isStarted else { return 0 }
        return TypingTest.wpm(characters: test.correctWordCharacters, seconds: test.elapsed(at: now))
    }

    /// Opening the screen: the corpus on first use, and a test unless one is already up.
    func open() {
        guard test == nil, !isLoading else { return }
        guard corpus == nil else { return newTest() }
        isLoading = true
        Task {
            corpus = await TypingCorpus.loadBundled()
            isLoading = false
            newTest()
        }
    }

    /// Leaving the screen ends whatever was on it, so the next visit starts clean.
    func close() {
        stopTicking()
        test = nil
        result = nil
        isNewBest = false
        fieldText = String(TypingFieldEdit.sentinel)
    }

    /// Hiding mid-test abandons it: the same words wait, unstarted, for a reopen.
    func abandonRunningTest() {
        guard isRunning, let test else { return }
        begin(test.restarted)
    }

    func newTest() {
        guard let corpus else { return }
        let config = store.config
        switch config.mode {
        case .time:
            let words = corpus.randomWords(
                count: Self.wordsAhead * 2, after: nil, using: &generator)
            begin(TypingTest(config: config, words: words))
        case .quote:
            guard
                let quote = corpus.randomQuote(
                    config.quoteLength, excluding: test?.quote?.id, using: &generator)
            else { return }
            begin(TypingTest(config: config, words: quote.words, quote: quote))
        }
    }

    /// The same words again, for another go at a quote or a run of words.
    func repeatTest() {
        guard let test else { return }
        begin(test.restarted)
    }

    func select(_ config: TypingTestConfig) {
        store.config = config
        newTest()
    }

    func clearHistory() {
        store.clear()
        isNewBest = false
    }

    /// Every change the field editor makes, replayed onto the test as keys.
    func edit(_ text: String) {
        guard var test, !test.isFinished else {
            // A refused key still reached the field editor; setting the text takes it back out.
            fieldText = test.map(TypingFieldEdit.text(for:)) ?? String(TypingFieldEdit.sentinel)
            return
        }
        now = clock()
        TypingFieldEdit.apply(from: fieldText, to: text, to: &test, at: now)
        if test.config.mode == .time, test.words.count - test.index < Self.wordsAhead,
            let corpus
        {
            test.appendWords(
                corpus.randomWords(count: Self.wordsAhead, after: test.words.last, using: &generator))
        }
        self.test = test
        fieldText = TypingFieldEdit.text(for: test)
        if test.isFinished {
            complete()
        } else if test.isStarted, ticker == nil {
            startTicking()
        }
    }

    private func begin(_ test: TypingTest) {
        stopTicking()
        self.test = test
        result = nil
        isNewBest = false
        fieldText = TypingFieldEdit.text(for: test)
        now = clock()
    }

    private func startTicking() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard var test, !test.isFinished else { return stopTicking() }
        now = clock()
        guard test.isOutOfTime(at: now) else { return }
        test.finish(at: now)
        self.test = test
        complete()
    }

    private func complete() {
        stopTicking()
        guard let test, let result = test.result(at: clock(), date: Date()) else { return }
        self.result = result
        isNewBest = store.add(result)
    }
}
