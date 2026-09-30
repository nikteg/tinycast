import SwiftUI

/// The test owns the keyboard, so the search field steps aside and ⇥ starts over, as in Monkeytype.
struct TypingPracticeScreen: PaletteScreen {
    let session: TypingPracticeSession
    let coordinator: TypingPracticeCoordinator

    /// No list: the text is the whole screen, and ↵ and ⌘K act on the test itself.
    struct Row: Identifiable {
        let id: Int
    }

    var rows: [Row] { [] }
    var hidesSearchField: Bool { true }
    var actsWithoutRows: Bool { true }

    var primaryActionTitle: String { "Next Test" }

    /// ↵ mid-test is a mistyped key, not a request to throw the test away.
    func hasPrimaryAction(at selection: Int) -> Bool { !session.isRunning }

    func activate(at selection: Int) {
        guard !session.isRunning else { return }
        session.newTest()
    }

    func secondary(at selection: Int) -> Bool { false }

    /// ⌘R restarts the test on screen, the same words from the top, as ⇧⇥ does.
    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard shortcut == .restart else { return false }
        session.repeatTest()
        return true
    }

    /// ⇥ is a new test at any point; ⇧⇥ the same words again.
    func tab(at selection: Int, backwards: Bool) -> Bool {
        if backwards {
            session.repeatTest()
        } else {
            session.newTest()
        }
        return true
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        var items = [
            PopoverMenuItem(title: "Next Test", systemImage: "arrow.clockwise", shortcut: "⇥") {
                session.newTest()
            },
            PopoverMenuItem(title: "Repeat Test", systemImage: "repeat", shortcut: "⌘R") {
                session.repeatTest()
            }
        ]
        if session.isFinished {
            items.append(
                PopoverMenuItem(title: "Copy Score Card", systemImage: "photo", shortcut: "⌘C") {
                    coordinator.copyScoreCard()
                })
        }
        items += configItems
        items.append(
            PopoverMenuItem(
                title: "Clear History", systemImage: "trash", startsSection: true,
                isDestructive: true
            ) {
                coordinator.clearHistory()
            })
        return PopoverMenuContent(header: "Typing Practice", items: items)
    }

    /// Every test kind as a row, so the keyboard reaches what the bar above the text offers.
    private var configItems: [PopoverMenuItem] {
        let current = session.config
        let times = TypingDuration.allCases.enumerated().map { index, duration in
            PopoverMenuItem(
                title: "Time: \(duration.seconds) Seconds", icon: .symbol("timer"),
                sectionTitle: index == 0 ? "Test" : nil, startsSection: index == 0,
                detail: current.mode == .time && current.duration == duration ? "Current" : nil
            ) {
                session.select(TypingTestConfig(mode: .time, duration: duration, quoteLength: current.quoteLength))
            }
        }
        let quotes = TypingQuoteLength.allCases.map { length in
            PopoverMenuItem(
                title: "Quote: \(length.title.capitalized)", icon: .symbol("quote.opening"),
                detail: current.mode == .quote && current.quoteLength == length ? "Current" : nil
            ) {
                session.select(TypingTestConfig(mode: .quote, duration: current.duration, quoteLength: length))
            }
        }
        return times + quotes
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(TypingPracticeView(session: session))
    }
}
