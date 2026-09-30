import Foundation

/// Progress over time, and the test the next one is set up as.
struct TypingHistory: Codable, Equatable, Sendable {
    /// Enough to chart months of daily practice without the file growing without bound.
    static let limit = 1000

    var config = TypingTestConfig()
    /// Oldest first.
    private(set) var records: [TypingRecord] = []

    /// True when the result beats every earlier test of the same kind.
    @discardableResult
    mutating func add(_ record: TypingRecord) -> Bool {
        let best = personalBest(for: record.config)
        records.append(record)
        if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
        return best.map { record.wpm > $0.wpm } ?? true
    }

    mutating func clear() {
        records = []
    }

    func personalBest(for config: TypingTestConfig) -> TypingRecord? {
        records.filter { $0.config == config }.max { $0.wpm < $1.wpm }
    }

    /// Nil until there are tests of this kind to average.
    func averageWPM(for config: TypingTestConfig, last count: Int) -> Double? {
        let recent = records.filter { $0.config == config }.suffix(count)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.wpm } / Double(recent.count)
    }

    func testCount(for config: TypingTestConfig) -> Int {
        records.count { $0.config == config }
    }
}
