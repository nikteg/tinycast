import Foundation

/// Greedy wrapping in a monospaced grid, so the view knows which line the caret is on.
enum TypingLineLayout {
    /// Ranges of word indices, one per line. A word longer than a line gets a line to itself.
    static func lines(wordLengths: [Int], columns: Int) -> [Range<Int>] {
        guard !wordLengths.isEmpty else { return [] }
        let columns = max(1, columns)
        var lines: [Range<Int>] = []
        var start = 0
        var used = 0
        for (index, length) in wordLengths.enumerated() {
            let needed = used == 0 ? length : used + 1 + length
            if needed > columns, used > 0 {
                lines.append(start..<index)
                start = index
                used = length
            } else {
                used = needed
            }
        }
        lines.append(start..<wordLengths.count)
        return lines
    }

    /// Monkeytype keeps the caret on the middle line once the first has been typed past.
    static func visibleLines(
        _ lines: [Range<Int>], caretWord: Int, count: Int
    ) -> ArraySlice<Range<Int>> {
        guard let caretLine = lines.firstIndex(where: { $0.contains(caretWord) }) else {
            return lines.prefix(count)
        }
        let first = max(0, min(caretLine - 1, lines.count - count))
        return lines[first..<min(lines.count, first + count)]
    }
}
