import Foundation

@main
@MainActor
struct TypingPracticeTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        typesAndAdvances()
        backspaceRules()
        endsQuotesOnTheLastWord()
        endsTimeTestsOnTheClock()
        scoresLikeMonkeytype()
        chartsEverySecond()
        wrapsIntoLines()
        bridgesTheTextField()
        picksWordsAndQuotes()
        keepsHistory()
        loadsTheBundledData()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static let time30 = TypingTestConfig(mode: .time, duration: .thirty)
    private static let quote = TypingTestConfig(mode: .quote, quoteLength: .short)

    private static func type(_ text: String, into test: inout TypingTest, at time: TimeInterval) {
        for character in text { test.type(character, at: time) }
    }

    static func typesAndAdvances() {
        var test = TypingTest(config: time30, words: ["the", "be", "of"])
        expect(!test.isStarted, "nothing runs until the first key")
        test.type(" ", at: 5)
        expect(!test.isStarted && test.index == 0, "a leading space neither starts nor skips a word")
        type("th", into: &test, at: 10)
        expect(test.startedAt == 10, "the first key starts the clock")
        expect(test.currentInput == "th", "letters collect in the word under the caret")
        type("e ", into: &test, at: 11)
        expect(test.index == 1 && test.currentInput.isEmpty, "space moves to the next word")
        test.type(" ", at: 11)
        expect(test.index == 1, "space on an empty word is swallowed")
        type(String(repeating: "x", count: 40), into: &test, at: 12)
        expect(
            test.currentInput.count == 2 + TypingTest.extraCharacterLimit,
            "extra letters stop at the limit past the word's end")
    }

    static func backspaceRules() {
        var test = TypingTest(config: time30, words: ["the", "be", "of", "and"])
        type("the bx ", into: &test, at: 0)
        test.backspace()
        expect(test.index == 1 && test.currentInput == "bx", "an empty word backs into a wrong one")
        test.backspace()
        expect(test.currentInput == "b", "and edited")
        test.backspace()
        test.backspace()
        expect(test.index == 1 && test.currentInput.isEmpty, "a correct word before it stays final")
        type("be ", into: &test, at: 1)
        test.backspace()
        expect(test.index == 2, "a correct word is final: backspace never returns to it")
        type("ox ", into: &test, at: 2)
        test.deleteWord()
        expect(test.index == 2 && test.currentInput.isEmpty, "⌥⌫ on an empty word clears the wrong one")
        type("of", into: &test, at: 3)
        test.deleteWord()
        expect(test.index == 2 && test.currentInput.isEmpty, "⌥⌫ clears the word in progress")
    }

    static func endsQuotesOnTheLastWord() {
        let text = TypingQuote(id: 1, text: "to be", source: "Hamlet")
        var test = TypingTest(config: quote, words: text.words, quote: text)
        type("to b", into: &test, at: 0)
        expect(!test.isFinished, "a quote runs until its last word")
        test.type("e", at: 4)
        expect(test.finishedAt == 4, "the last word ends the quote the moment it is right")
        test.type("x", at: 5)
        expect(test.currentInput == "be", "a finished test takes no more keys")

        var wrong = TypingTest(config: quote, words: text.words, quote: text)
        type("to bx ", into: &wrong, at: 2)
        expect(wrong.isFinished, "space on a wrong last word still ends it")
        expect(wrong.characterCounts.incorrect == 1, "and the mistake is counted")
    }

    static func endsTimeTestsOnTheClock() {
        var test = TypingTest(config: time30, words: ["the", "be"])
        test.type("t", at: 100)
        expect(!test.isOutOfTime(at: 129.9), "a time test runs its full length")
        expect(test.isOutOfTime(at: 130), "and stops on it")
        test.finish(at: 135)
        expect(test.elapsed(at: 200) == 30, "a late tick never stretches the test")
        test.appendWords(["of"])
        expect(test.words.count == 3, "a time test takes more words as it goes")
    }

    static func scoresLikeMonkeytype() {
        let minute = TypingTestConfig(mode: .time, duration: .sixty)
        var test = TypingTest(config: minute, words: ["the", "be", "of", "and"])
        type("the bx of an", into: &test, at: 0)
        test.finish(at: 60)
        let counts = test.characterCounts
        expect(
            counts == .init(correct: 8, incorrect: 1, extra: 0, missed: 0),
            "a cut-off last word misses nothing: \(counts)")
        expect(test.correctWordCharacters == 3 + 1 + 2 + 1 + 2, "correct words, their spaces, and a clean prefix")
        guard let result = test.result(at: 60, date: .distantPast) else {
            return expect(false, "a typed test has a result")
        }
        expect(abs(result.wpm - 9.0 / 5) < 0.0001, "WPM is correct characters over five, per minute")
        expect(abs(result.raw - 12.0 / 5) < 0.0001, "raw counts every key and space")
        expect(abs(result.accuracy - 1000.0 / 12) < 0.0001, "a wrong word's space is a wrong key too")

        var missed = TypingTest(config: quote, words: ["abc", "de"])
        type("a de", into: &missed, at: 0)
        expect(missed.characterCounts.missed == 2, "a passed word misses what was never typed")
        expect(
            TypingTest(config: time30, words: ["a"]).result(at: 10, date: .distantPast) == nil,
            "an untouched test has no result")
    }

    static func chartsEverySecond() {
        let keys: [TypingTest.Keystroke] = [
            .init(time: 0, isCorrect: true), .init(time: 0.5, isCorrect: false),
            .init(time: 1.5, isCorrect: true), .init(time: 2.2, isCorrect: true)
        ]
        let samples = TypingSample.series(keys, duration: 2.5)
        expect(samples.map(\.time) == [1, 2, 2.5], "a sample per second, and the part-second at the end")
        expect(samples[0].errors == 1 && samples[0].raw == 2 * 12, "the opening second counts its first key")
        expect(samples[1].wpm == 2.0 / 5 / (2.0 / 60), "WPM is cumulative correct keys")
        expect(abs(samples[2].raw - 1.0 / 5 / (0.5 / 60)) < 0.0001, "a part-second is scaled to its length")
        expect(TypingSample.consistency([80, 80, 80]) == 100, "a steady pace is fully consistent")
        expect(TypingSample.consistency([20, 140]) < 50, "a ragged one is not")
    }

    static func wrapsIntoLines() {
        let lines = TypingLineLayout.lines(wordLengths: [3, 3, 3, 12, 2], columns: 8)
        expect(lines == [0..<2, 2..<3, 3..<4, 4..<5], "words wrap on the column count: \(lines)")
        expect(
            TypingLineLayout.visibleLines(lines, caretWord: 0, count: 3) == lines[0..<3],
            "the first line leads until it is typed past")
        expect(
            TypingLineLayout.visibleLines(lines, caretWord: 3, count: 3) == lines[1..<4],
            "then the caret's line sits in the middle")
        expect(
            TypingLineLayout.visibleLines(lines, caretWord: 4, count: 3) == lines[1..<4],
            "and the end of a quote stays in view")
    }

    static func bridgesTheTextField() {
        var test = TypingTest(config: time30, words: ["the", "be", "of"])
        var field = TypingFieldEdit.text(for: test)
        func edit(_ new: String, at time: TimeInterval = 0) {
            TypingFieldEdit.apply(from: field, to: new, to: &test, at: time)
            field = TypingFieldEdit.text(for: test)
        }
        edit(field + "tha")
        expect(test.currentInput == "tha", "an insert is typed")
        edit(String(field.dropLast()))
        expect(test.currentInput == "th", "a deleted character is a backspace")
        edit(field + "e bx ")
        expect(test.index == 2, "a space inside an insert still advances")
        edit("")
        expect(test.index == 1 && test.currentInput == "bx", "deleting the sentinel backs into the wrong word")
        edit(String(TypingFieldEdit.sentinel))
        expect(test.currentInput.isEmpty, "several characters at once clear the word")
    }

    static func picksWordsAndQuotes() {
        var generator = SeededGenerator(seed: 7)
        let corpus = TypingCorpus(
            words: ["a", "b"],
            quotes: [
                .init(id: 1, text: String(repeating: "x", count: 50), source: ""),
                .init(id: 2, text: String(repeating: "y", count: 50), source: ""),
                .init(id: 3, text: String(repeating: "z", count: 200), source: "")
            ])
        let words = corpus.randomWords(count: 50, after: "a", using: &generator)
        expect(words.count == 50, "as many words as asked for")
        expect(words.first != "a" && zip(words, words.dropFirst()).allSatisfy { $0 != $1 }, "never a repeat")
        let short = corpus.randomQuote(.short, excluding: 1, using: &generator)
        expect(short?.id == 2, "a quote from its group, never the one just typed")
        expect(corpus.randomQuote(.medium, excluding: 3, using: &generator)?.id == 3, "unless it is the only one")
        expect(corpus.randomQuote(.thicc, excluding: nil, using: &generator) == nil, "an empty group has none")
    }

    static func keepsHistory() {
        var history = TypingHistory()
        let slow = TypingRecord(date: .distantPast, config: time30, wpm: 50, raw: 55, accuracy: 95, consistency: 70)
        let fast = TypingRecord(date: .distantPast, config: time30, wpm: 80, raw: 82, accuracy: 97, consistency: 75)
        let other = TypingRecord(date: .distantPast, config: quote, wpm: 40, raw: 45, accuracy: 90, consistency: 60)
        expect(history.add(slow), "the first test is a personal best")
        expect(history.add(fast), "a faster one is too")
        expect(!history.add(slow), "a slower one is not")
        expect(history.add(other), "bests are kept per kind of test")
        expect(history.personalBest(for: time30) == fast, "the best is the fastest of its kind")
        expect(history.averageWPM(for: time30, last: 2) == 65, "the average covers the last tests")
        expect(history.testCount(for: time30) == 3, "tests are counted per kind")
        for _ in 0..<TypingHistory.limit { history.add(slow) }
        expect(history.records.count == TypingHistory.limit, "history stops growing at its limit")
        let data = try? JSONEncoder().encode(history)
        let decoded = data.flatMap { try? JSONDecoder().decode(TypingHistory.self, from: $0) }
        expect(decoded == history, "history round-trips through JSON")
    }

    static func loadsTheBundledData() {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Tinycast/Features/TypingPractice/Resources")
        guard let words = try? Data(contentsOf: folder.appendingPathComponent("TypingWords.generated.json")),
            let quotes = try? Data(contentsOf: folder.appendingPathComponent("TypingQuotes.generated.json")),
            let corpus = try? TypingCorpus(wordsData: words, quotesData: quotes)
        else { return expect(false, "the generated data decodes") }
        expect(corpus.words.count == 200, "Monkeytype's 200 English words")
        for length in TypingQuoteLength.allCases {
            expect(corpus.quotes.contains { length.contains($0.text.count) }, "\(length) has quotes")
        }
        expect(
            corpus.quotes.allSatisfy { !$0.text.contains("  ") && !$0.words.isEmpty },
            "every quote splits cleanly into words")
    }
}

/// Deterministic picks, so the corpus tests do not flake.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
