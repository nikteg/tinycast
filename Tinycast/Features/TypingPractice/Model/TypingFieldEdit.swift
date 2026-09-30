import Foundation

/// Turns edits to the hidden text field into keystrokes, so the field editor keeps IME and repeat.
enum TypingFieldEdit {
    /// Leads the field's text: an empty word still has something for a backspace to delete.
    static let sentinel: Character = "\u{200B}"

    static func text(for test: TypingTest) -> String {
        String(sentinel) + test.currentInput
    }

    /// One deleted character is a backspace; more at once is ⌥⌫ or ⌘⌫, which clear the word.
    static func apply(from old: String, to new: String, to test: inout TypingTest, at now: TimeInterval) {
        let old = Array(old)
        let new = Array(new)
        let shared = zip(old, new).prefix { $0 == $1 }.count
        switch old.count - shared {
        case 0: break
        case 1: test.backspace()
        default: test.deleteWord()
        }
        for character in new[shared...] where character != sentinel && !character.isNewline {
            test.type(character, at: now)
        }
    }
}
