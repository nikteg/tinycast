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
        spansReadLikeW()
        printsTheWholeLine()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func spansReadLikeW() {
        expect(UptimeReport.span(42) == "42 secs", "under a minute counts seconds")
        expect(UptimeReport.span(1) == "1 sec", "one second is singular")
        expect(UptimeReport.span(60) == "1 min", "exactly a minute is not rounded")
        expect(UptimeReport.span(5 * 60 + 29) == "5 mins", "rounds down below the half minute")
        expect(UptimeReport.span(5 * 60 + 30) == "6 mins", "rounds up from the half minute")
        expect(UptimeReport.span(3600) == "1 hr", "a whole hour names its unit")
        expect(UptimeReport.span(2 * 3600 + 14 * 60) == "2:14", "hours and minutes read as a clock")
        expect(UptimeReport.span(3600 + 5 * 60) == "1:05", "minutes are zero padded")
        let span = UptimeReport.span(3 * 86_400 + 2 * 3600 + 14 * 60)
        expect(span == "3 days, 2:14", "days lead: \(span)")
        expect(UptimeReport.span(86_400 + 3600) == "1 day, 1 hr", "one day is singular")
        expect(UptimeReport.span(-5) == "0 sec", "a clock set back never goes negative")
    }

    static func printsTheWholeLine() {
        let report = UptimeReport(
            clock: "9:36", sinceBoot: 3 * 86_400 + 2 * 3600 + 14 * 60, users: 6,
            loadAverages: [11.48, 9.98, 6.9])
        let line = report.line
        expect(line == "9:36 up 3 days, 2:14, 6 users, load averages: 11.48 9.98 6.90", line)
        let single = UptimeReport(clock: "9:36", sinceBoot: 90, users: 1, loadAverages: [1, 2, 3])
        expect(single.line == "9:36 up 2 mins, 1 user, load averages: 1.00 2.00 3.00", single.line)
    }
}
