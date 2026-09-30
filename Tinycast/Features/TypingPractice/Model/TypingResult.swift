import Foundation

/// One point on the results chart: the second it closes, and how that second went.
struct TypingSample: Codable, Equatable, Sendable {
    let time: TimeInterval
    /// Correct keys so far, as words per minute, so the line settles rather than jitters.
    let wpm: Double
    /// Every key in this second alone, as words per minute.
    let raw: Double
    let errors: Int

    /// One sample per whole second, plus the part-second a quote ended in.
    static func series(_ keystrokes: [TypingTest.Keystroke], duration: TimeInterval) -> [Self] {
        guard duration > 0 else { return [] }
        var marks = (1...max(1, Int(duration))).map(TimeInterval.init).filter { $0 <= duration }
        if marks.last.map({ duration - $0 > 0.05 }) ?? true { marks.append(duration) }
        var samples: [Self] = []
        var previous: TimeInterval = 0
        for mark in marks {
            // The first key lands at zero, so the opening second is closed at both ends.
            let keys = keystrokes.filter {
                ($0.time > previous || previous == 0) && $0.time <= mark
            }
            let correctSoFar = keystrokes.count { $0.isCorrect && $0.time <= mark }
            samples.append(
                Self(
                    time: mark,
                    wpm: TypingTest.wpm(characters: correctSoFar, seconds: mark),
                    raw: TypingTest.wpm(characters: keys.count, seconds: mark - previous),
                    errors: keys.count { !$0.isCorrect }))
            previous = mark
        }
        return samples
    }

    /// Monkeytype's consistency: the spread of raw speed per second, mapped onto 0–100.
    static func consistency(_ raws: [Double]) -> Double {
        guard raws.count > 1 else { return raws.isEmpty ? 0 : 100 }
        let mean = raws.reduce(0, +) / Double(raws.count)
        guard mean > 0 else { return 0 }
        let variance = raws.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(raws.count)
        let cov = variance.squareRoot() / mean
        return 100 * (1 - tanh(cov + pow(cov, 3) / 3 + pow(cov, 5) / 5))
    }
}

/// A finished test, as the results screen and the score card show it.
struct TypingResult: Codable, Equatable, Sendable {
    let date: Date
    let config: TypingTestConfig
    let wpm: Double
    let raw: Double
    let accuracy: Double
    let consistency: Double
    let characters: TypingTest.CharacterCounts
    let duration: TimeInterval
    let samples: [TypingSample]
    let quote: TypingQuote?

    var record: TypingRecord {
        TypingRecord(
            date: date, config: config, wpm: wpm, raw: raw, accuracy: accuracy,
            consistency: consistency)
    }
}

/// What history keeps of a result; the chart is only ever shown for the test just taken.
struct TypingRecord: Codable, Equatable, Sendable {
    let date: Date
    let config: TypingTestConfig
    let wpm: Double
    let raw: Double
    let accuracy: Double
    let consistency: Double
}
