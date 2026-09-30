import AppKit
import SwiftUI

/// The screen's body: a hidden field takes the keys, and the text or the results fill the palette.
struct TypingPracticeView: View {
    let session: TypingPracticeSession
    @Environment(PaletteState.self) private var palette
    @Environment(\.metrics) private var metrics
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            inputField
            if let result = session.result {
                TypingResultView(
                    result: result, isNewBest: session.isNewBest, history: session.store.history)
            } else if let test = session.test {
                testView(test)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, metrics.spacing.xxl)
        .padding(.vertical, metrics.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
        .onAppear {
            session.open()
            fieldFocused = true
        }
        // Every show bumps the token, and the palette hands focus to its hidden search field then.
        .onChange(of: palette.focusToken) { fieldFocused = true }
        .onChange(of: palette.isVisible) { _, visible in
            if !visible { session.abandonRunningTest() }
        }
        .onChange(of: fieldFocused) { _, focused in palette.noteEditingField(focused) }
        .onDisappear {
            palette.noteEditingField(false)
            session.close()
        }
    }

    private static let backtab = KeyEquivalent("\u{19}")

    /// Kept for its field editor alone: IME, key repeat and ⌥⌫ all arrive as edits to its text.
    private var inputField: some View {
        TextField("", text: Binding(get: { session.fieldText }, set: { session.edit($0) }))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .focused($fieldFocused)
            // A caret moved inside the field would turn the next key into an edit mid-word.
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { _ in .handled }
            // AppKit spells ⇧⇥ as backtab, which the palette's own ⇥ handler never matches.
            .onKeyPress(keys: [Self.backtab], phases: .down) { _ in
                session.repeatTest()
                return .handled
            }
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityLabel("Typing input")
    }

    private func testView(_ test: TypingTest) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xl) {
            TypingConfigBar(config: session.config) { config in
                session.select(config)
                fieldFocused = true
            }
            .frame(maxWidth: .infinity)
            .opacity(session.isRunning ? 0 : 1)
            .allowsHitTesting(!session.isRunning)
            Spacer(minLength: 0)
            progress(test)
            TypingTextView(test: test, isWaiting: !session.isRunning)
                .overlay {
                    if !fieldFocused {
                        Text("Click here to focus")
                            .font(metrics.typography.rowTitle)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.panelScrim)
                    }
                }
            Spacer(minLength: 0)
            hints
        }
        .animation(.easeOut(duration: Theme.Duration.hover), value: session.isRunning)
    }

    /// The countdown or the words left, with the pace so far once it means something.
    private func progress(_ test: TypingTest) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: metrics.spacing.xl) {
            Group {
                if let seconds = session.secondsLeft {
                    Text(verbatim: String(seconds))
                } else {
                    Text(verbatim: "\(test.index)/\(test.words.count)")
                }
            }
            .font(.system(size: metrics.scaled(Theme.Typing.textSize), design: .monospaced))
            .foregroundStyle(Theme.Colors.typingCaret)
            .monospacedDigit()
            if session.isRunning {
                Text(verbatim: "\(Int(session.liveWPM.rounded())) wpm")
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .monospacedDigit()
            }
        }
        .opacity(session.isRunning ? 1 : 0)
    }

    private var hints: some View {
        HStack(spacing: metrics.spacing.xxl) {
            hint("⇥", "next test")
            hint("⌘R", "repeat")
            hint("esc", "close")
        }
        .frame(maxWidth: .infinity)
        .opacity(session.isRunning ? 0 : 1)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: metrics.spacing.xs) {
            KeyCapChip(text: key, style: .outline, scale: .compact)
            Text(label)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

/// Time or quote, then the length of either; the chosen ones in full ink.
struct TypingConfigBar: View {
    let config: TypingTestConfig
    let select: (TypingTestConfig) -> Void
    @Environment(\.metrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            ForEach(TypingTestMode.allCases, id: \.self) { mode in
                option(mode.title, isOn: config.mode == mode) {
                    var next = config
                    next.mode = mode
                    select(next)
                }
            }
            Rectangle()
                .fill(Theme.Colors.separator)
                .frame(width: 1, height: metrics.size.keyCap)
            switch config.mode {
            case .time:
                ForEach(TypingDuration.allCases, id: \.self) { duration in
                    option(duration.title, isOn: config.duration == duration) {
                        var next = config
                        next.duration = duration
                        select(next)
                    }
                }
            case .quote:
                ForEach(TypingQuoteLength.allCases, id: \.self) { length in
                    option(length.title, isOn: config.quoteLength == length) {
                        var next = config
                        next.quoteLength = length
                        select(next)
                    }
                }
            }
        }
        .font(metrics.typography.rowTrailing)
    }

    private func option(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        TypingConfigOption(title: title, isOn: isOn, action: action)
    }
}

/// Its own view so each option keeps its hover to itself rather than redrawing the bar.
private struct TypingConfigOption: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(
                    isOn
                        ? Theme.Colors.textPrimary
                        : isHovered ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.Duration.hover), value: isHovered)
    }
}

/// Three lines of the test, the caret's in the middle, drawn on a monospaced grid.
struct TypingTextView: View {
    let test: TypingTest
    /// True until the first key, while the caret blinks.
    let isWaiting: Bool
    @Environment(\.metrics) private var metrics

    private var fontSize: CGFloat { metrics.scaled(Theme.Typing.textSize) }
    private var nsFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    private var characterWidth: CGFloat {
        ("0" as NSString).size(withAttributes: [.font: nsFont]).width
    }
    private var lineHeight: CGFloat { NSLayoutManager().defaultLineHeight(for: nsFont) }
    private var lineSpacing: CGFloat { metrics.scaled(Theme.Typing.lineSpacing) }

    var body: some View {
        let lineCount = CGFloat(Theme.Typing.visibleLines)
        GeometryReader { proxy in
            let columns = Int(proxy.size.width / characterWidth)
            let lines = TypingLineLayout.lines(wordLengths: displayLengths, columns: columns)
            let visible = TypingLineLayout.visibleLines(
                lines, caretWord: test.index, count: Theme.Typing.visibleLines)
            VStack(alignment: .leading, spacing: lineSpacing) {
                ForEach(Array(visible), id: \.lowerBound) { line in
                    Text(text(for: line))
                        .font(.system(size: fontSize, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(height: lineHeight, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if line.contains(test.index) { caret(column: caretColumn(in: line)) }
                        }
                }
            }
        }
        .frame(height: lineCount * lineHeight + (lineCount - 1) * lineSpacing)
    }

    /// A word takes the room of its target or of what was typed, whichever is longer.
    private var displayLengths: [Int] {
        test.words.indices.map { index in
            let typed = index <= test.index ? test.inputs[index].count : 0
            return max(test.words[index].count, typed)
        }
    }

    private func caretColumn(in line: Range<Int>) -> Int {
        let before = displayLengths[line.lowerBound..<test.index].reduce(0) { $0 + $1 + 1 }
        return before + test.currentInput.count
    }

    private func caret(column: Int) -> some View {
        Rectangle()
            .fill(Theme.Colors.typingCaret)
            .frame(width: Theme.Typing.caretWidth)
            .offset(x: CGFloat(column) * characterWidth - Theme.Typing.caretWidth / 2)
            .animation(.easeOut(duration: Theme.Typing.caretGlide), value: column)
            .phaseAnimator([1.0, 0.0]) { content, phase in
                content.opacity(isWaiting ? phase : 1)
            } animation: { _ in
                .easeInOut(duration: Theme.Typing.caretBlink)
            }
    }

    private func text(for line: Range<Int>) -> AttributedString {
        var string = AttributedString()
        for index in line {
            if index > line.lowerBound { string += AttributedString(" ") }
            string += word(index)
        }
        return string
    }

    /// Monkeytype's colouring: a wrong letter shows the one wanted, in red; extras show as typed.
    private func word(_ index: Int) -> AttributedString {
        let target = Array(test.words[index])
        let typed = index <= test.index ? Array(test.inputs[index]) : []
        var word = AttributedString()
        for offset in 0..<max(target.count, typed.count) {
            let isTarget = offset < target.count
            var letter = AttributedString(String(isTarget ? target[offset] : typed[offset]))
            letter.foregroundColor =
                if !isTarget {
                    Theme.Colors.typingExtra
                } else if offset >= typed.count {
                    Theme.Colors.textTertiary
                } else if typed[offset] == target[offset] {
                    Theme.Colors.textPrimary
                } else {
                    Theme.Colors.destructive
                }
            word += letter
        }
        if index < test.index, test.inputs[index] != test.words[index] {
            word.underlineStyle = Text.LineStyle(pattern: .solid, color: Theme.Colors.destructive)
        }
        return word
    }
}
