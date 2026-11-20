import Foundation

@main
@MainActor
struct UptimeTests {
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
        spansRead()
        printsTheWholeLine()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func spansRead() {
        expect(UptimeReport.span(42) == "less than a minute", "under a minute names no unit")
        expect(UptimeReport.span(60) == "1 minute", "one minute is singular")
        expect(UptimeReport.span(5 * 60 + 59) == "5 minutes", "seconds are dropped, not rounded")
        expect(UptimeReport.span(3600) == "1 hour", "zero units are left out")
        let span = UptimeReport.span(3 * 86_400 + 2 * 3600 + 14 * 60)
        expect(span == "3 days 2 hours 14 minutes", "days lead: \(span)")
        expect(UptimeReport.span(86_400 + 60) == "1 day 1 minute", "an empty middle unit is skipped")
        expect(UptimeReport.span(-5) == "less than a minute", "a clock set back never goes negative")
    }

    static func printsTheWholeLine() {
        let report = UptimeReport(sinceBoot: 2 * 86_400 + 14 * 3600 + 22 * 60, booted: "Sat 11 Oct 19:21")
        let line = report.line
        expect(line == "Up 2 days 14 hours 22 minutes · since Sat 11 Oct 19:21", line)
    }
}
