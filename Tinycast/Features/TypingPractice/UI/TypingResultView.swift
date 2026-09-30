import SwiftUI

/// The results as the palette shows them: the stats, then how this test sits in the history.
struct TypingResultView: View {
    let result: TypingResult
    let isNewBest: Bool
    let history: TypingHistory
    @Environment(\.metrics) private var metrics

    /// Monkeytype's window for a recent average.
    private static let averageCount = 10

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xxl) {
            Spacer(minLength: 0)
            TypingResultStats(result: result)
            progress
            if let quote = result.quote, !quote.source.isEmpty {
                Text(verbatim: "— \(quote.source)")
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: metrics.spacing.xxl) {
                hint("⇥", "next test")
                hint("⌘R", "repeat")
                hint("⌘C", "copy score card")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var progress: some View {
        HStack(spacing: metrics.spacing.xxl) {
            if isNewBest {
                Label("New personal best", systemImage: "crown")
                    .foregroundStyle(Theme.Colors.typingCaret)
            } else if let best = history.personalBest(for: result.config) {
                Text(verbatim: "Personal best \(Int(best.wpm.rounded())) wpm")
            }
            if let average = history.averageWPM(for: result.config, last: Self.averageCount) {
                Text(verbatim: "Average \(Int(average.rounded())) wpm")
                    .tooltip("Your last \(Self.averageCount) \(result.config.title) tests")
            }
            Text(verbatim: "\(history.testCount(for: result.config)) tests")
        }
        .font(metrics.typography.rowTrailing)
        .foregroundStyle(Theme.Colors.textSecondary)
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

/// WPM and accuracy large, the chart beside them, and the smaller numbers underneath.
struct TypingResultStats: View {
    let result: TypingResult
    @Environment(\.metrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xxl) {
            HStack(alignment: .top, spacing: metrics.spacing.xxl) {
                VStack(alignment: .leading, spacing: metrics.spacing.md) {
                    hero("wpm", Self.whole(result.wpm))
                    hero("acc", "\(Self.whole(result.accuracy))%")
                }
                .fixedSize()
                TypingChart(samples: result.samples, duration: result.duration)
            }
            HStack(alignment: .top, spacing: metrics.spacing.xxl) {
                stat("test type", result.config.title)
                stat("raw", Self.whole(result.raw))
                stat("characters", characters)
                    .tooltip("correct / incorrect / extra / missed")
                stat("consistency", "\(Self.whole(result.consistency))%")
                stat("time", "\(Self.whole(result.duration))s")
            }
        }
    }

    private var characters: String {
        let counts = result.characters
        return "\(counts.correct)/\(counts.incorrect)/\(counts.extra)/\(counts.missed)"
    }

    static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func hero(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(metrics.typography.sectionHeader)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(verbatim: value)
                .font(.system(size: metrics.scaled(Theme.Typing.heroSize), weight: .semibold))
                .foregroundStyle(Theme.Colors.typingCaret)
                .monospacedDigit()
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xxs) {
            Text(label)
                .font(metrics.typography.sectionHeader)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(verbatim: value)
                .font(metrics.typography.calcResult)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

/// WPM over the test in the caret's colour, raw speed faint beneath it, and red where keys went wrong.
struct TypingChart: View {
    let samples: [TypingSample]
    let duration: TimeInterval
    @Environment(\.metrics) private var metrics

    private var ceiling: Double {
        let peak = samples.map { max($0.wpm, $0.raw) }.max() ?? 0
        return max(10, (peak / 10).rounded(.up) * 10)
    }

    var body: some View {
        let ceiling = ceiling
        Canvas { context, size in
            guard samples.count > 1, duration > 0 else { return }
            func point(_ time: TimeInterval, _ value: Double) -> CGPoint {
                CGPoint(
                    x: size.width * time / duration,
                    y: size.height * (1 - min(value, ceiling) / ceiling))
            }
            var raw = Path()
            var wpm = Path()
            for (index, sample) in samples.enumerated() {
                if index == 0 {
                    raw.move(to: point(sample.time, sample.raw))
                    wpm.move(to: point(sample.time, sample.wpm))
                } else {
                    raw.addLine(to: point(sample.time, sample.raw))
                    wpm.addLine(to: point(sample.time, sample.wpm))
                }
            }
            let line = StrokeStyle(lineWidth: Theme.Typing.chartLine, lineCap: .round, lineJoin: .round)
            context.stroke(raw, with: .color(Theme.Colors.textTertiary), style: line)
            context.stroke(wpm, with: .color(Theme.Colors.typingCaret), style: line)
            let dot = Theme.Typing.chartErrorDot
            for sample in samples where sample.errors > 0 {
                let center = point(sample.time, sample.raw)
                let rect = CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)
                context.fill(Path(ellipseIn: rect), with: .color(Theme.Colors.destructive))
            }
        }
        .frame(height: metrics.scaled(Theme.Typing.chartHeight))
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) { axisLabel(String(Int(ceiling))) }
        .overlay(alignment: .bottomTrailing) { axisLabel("\(Int(duration.rounded()))s") }
    }

    private func axisLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(metrics.typography.keyCap)
            .foregroundStyle(Theme.Colors.textTertiary)
            .monospacedDigit()
    }
}

/// The image ⌘C copies: the same stats on a page of their own, with a line saying what it is.
struct TypingScoreCard: View {
    let result: TypingResult
    let isNewBest: Bool
    let personalBest: TypingRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            HStack {
                Label("Typing Practice", systemImage: "keyboard")
                    .font(Theme.Typography.panelTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(result.date, format: .dateTime.day().month().year())
                    .font(Theme.Typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            TypingResultStats(result: result)
            if isNewBest {
                Label("New personal best", systemImage: "crown")
                    .font(Theme.Typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.typingCaret)
            } else if let personalBest {
                Text(verbatim: "Personal best \(TypingResultStats.whole(personalBest.wpm)) wpm")
                    .font(Theme.Typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.xxxl)
        .frame(width: Theme.Typing.scoreCardWidth)
        .background(Theme.Colors.scoreCardSurface)
    }
}
