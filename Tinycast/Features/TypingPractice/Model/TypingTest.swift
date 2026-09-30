import Foundation

/// One test in progress, with Monkeytype's rules. Every time is the caller's clock, in seconds.
struct TypingTest: Equatable, Sendable {
    struct Keystroke: Equatable, Sendable {
        /// Seconds since the first keystroke.
        let time: TimeInterval
        let isCorrect: Bool
    }

    /// Past this many characters beyond a word's end, further keys are dropped rather than drawn.
    static let extraCharacterLimit = 20

    let config: TypingTestConfig
    let quote: TypingQuote?
    private(set) var words: [String]
    /// What was typed for each word up to and including `index`.
    private(set) var inputs: [String] = [""]
    private(set) var index = 0
    private(set) var keystrokes: [Keystroke] = []
    /// Nil until the first key, which is what starts the clock.
    private(set) var startedAt: TimeInterval?
    private(set) var finishedAt: TimeInterval?

    init(config: TypingTestConfig, words: [String], quote: TypingQuote? = nil) {
        self.config = config
        self.words = words
        self.quote = quote
    }

    /// The same words or quote again, untouched.
    var restarted: TypingTest { TypingTest(config: config, words: words, quote: quote) }

    var isStarted: Bool { startedAt != nil }
    var isFinished: Bool { finishedAt != nil }
    var currentInput: String { inputs[index] }

    func elapsed(at now: TimeInterval) -> TimeInterval {
        guard let startedAt else { return 0 }
        let elapsed = (finishedAt ?? now) - startedAt
        guard config.mode == .time else { return elapsed }
        return min(elapsed, TimeInterval(config.duration.seconds))
    }

    /// Only a time test runs out; a quote ends on its last word.
    func isOutOfTime(at now: TimeInterval) -> Bool {
        config.mode == .time && isStarted
            && elapsed(at: now) >= TimeInterval(config.duration.seconds)
    }

    /// A time test is endless, so the caller keeps the list ahead of the caret.
    mutating func appendWords(_ more: [String]) {
        words += more
    }

    mutating func type(_ character: Character, at now: TimeInterval) {
        guard !isFinished else { return }
        if character == " " { return space(at: now) }
        let target = Array(words[index])
        let position = inputs[index].count
        guard position < target.count + Self.extraCharacterLimit else { return }
        begin(at: now)
        record(position < target.count && target[position] == character, at: now)
        inputs[index].append(character)
        // The last word ends a quote as soon as it is right; nothing follows it to press space for.
        if index == words.count - 1, config.mode == .quote, inputs[index] == words[index] {
            finish(at: now)
        }
    }

    /// Space on an empty word is swallowed, as Monkeytype does, so a double space never skips one.
    private mutating func space(at now: TimeInterval) {
        guard !inputs[index].isEmpty else { return }
        record(inputs[index] == words[index], at: now)
        guard index < words.count - 1 else { return finish(at: now) }
        index += 1
        inputs.append("")
    }

    /// Stepping back into the previous word is allowed only while that word is wrong.
    mutating func backspace() {
        guard !isFinished else { return }
        if !inputs[index].isEmpty {
            inputs[index].removeLast()
        } else if canReturnToPreviousWord {
            inputs.removeLast()
            index -= 1
        }
    }

    /// ⌥⌫: the word in progress, or else the wrong word before it.
    mutating func deleteWord() {
        guard !isFinished else { return }
        if inputs[index].isEmpty {
            guard canReturnToPreviousWord else { return }
            inputs.removeLast()
            index -= 1
        }
        inputs[index] = ""
    }

    private var canReturnToPreviousWord: Bool {
        index > 0 && inputs[index - 1] != words[index - 1]
    }

    mutating func finish(at now: TimeInterval) {
        guard let startedAt, !isFinished else { return }
        finishedAt =
            config.mode == .time
            ? min(now, startedAt + TimeInterval(config.duration.seconds)) : now
    }

    private mutating func begin(at now: TimeInterval) {
        if startedAt == nil { startedAt = now }
    }

    private mutating func record(_ isCorrect: Bool, at now: TimeInterval) {
        begin(at: now)
        keystrokes.append(Keystroke(time: now - (startedAt ?? now), isCorrect: isCorrect))
    }
}

extension TypingTest {
    /// How the typed text compares with the target, character by character.
    struct CharacterCounts: Codable, Equatable, Sendable {
        var correct = 0
        var incorrect = 0
        var extra = 0
        var missed = 0
    }

    /// Only a passed word can miss letters; a time test's last word was cut off, not skipped.
    var characterCounts: CharacterCounts {
        var counts = CharacterCounts()
        for (position, input) in inputs.enumerated() {
            let typed = Array(input)
            let target = Array(words[position])
            let isCommitted = position < index || (isFinished && config.mode == .quote)
            for (offset, character) in typed.enumerated() {
                if offset >= target.count {
                    counts.extra += 1
                } else if character == target[offset] {
                    counts.correct += 1
                } else {
                    counts.incorrect += 1
                }
            }
            if isCommitted {
                counts.missed += max(0, target.count - typed.count)
            }
        }
        return counts
    }

    /// Monkeytype's WPM: characters of fully correct words plus the spaces after them, over five.
    var correctWordCharacters: Int {
        var total = 0
        for (position, input) in inputs.enumerated() {
            let target = words[position]
            if input == target {
                total += target.count + (position < index ? 1 : 0)
            } else if position == index, !isFinished || config.mode == .time,
                target.hasPrefix(input)
            {
                total += input.count
            }
        }
        return total
    }

    /// Everything typed, right or wrong, with the spaces between words: the basis of raw WPM.
    var typedCharacters: Int {
        inputs.reduce(0) { $0 + $1.count } + index
    }

    func result(at now: TimeInterval, date: Date) -> TypingResult? {
        let seconds = elapsed(at: now)
        guard seconds > 0, !keystrokes.isEmpty else { return nil }
        let samples = TypingSample.series(keystrokes, duration: seconds)
        let correctKeys = keystrokes.count { $0.isCorrect }
        return TypingResult(
            date: date, config: config,
            wpm: Self.wpm(characters: correctWordCharacters, seconds: seconds),
            raw: Self.wpm(characters: typedCharacters, seconds: seconds),
            accuracy: 100 * Double(correctKeys) / Double(keystrokes.count),
            consistency: TypingSample.consistency(samples.map(\.raw)),
            characters: characterCounts, duration: seconds, samples: samples, quote: quote)
    }

    static func wpm(characters: Int, seconds: TimeInterval) -> Double {
        guard seconds > 0 else { return 0 }
        return Double(characters) / 5 / (seconds / 60)
    }
}
