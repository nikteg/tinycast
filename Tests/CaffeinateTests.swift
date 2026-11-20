import Foundation

@main
@MainActor
struct CaffeinateTests {
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
        lastsAsAsked()
        saysWhatItDoes()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static func lastsAsAsked() {
        let forever = Caffeination.lasting(nil, now: start)
        expect(forever == .indefinitely, "no length is until turned off")
        expect(!forever.hasEnded(now: .distantFuture), "and never ends on its own")
        let hour = Caffeination.lasting(3600, now: start)
        expect(hour.endsAt == start + 3600, "a length ends that far from now")
        expect(!hour.hasEnded(now: start + 3599) && hour.hasEnded(now: start + 3600), "on the second")
        expect(Caffeination.presets.first == .some(nil), "until turned off is offered first")
    }

    static func saysWhatItDoes() {
        expect(Caffeination.title(for: nil) == "Caffeinate Until Turned Off", "the open-ended row")
        expect(Caffeination.title(for: 1800) == "Caffeinate for 30 minutes", "a timed row")
        expect(Caffeination.indefinitely.status(until: nil) == "Caffeinated until turned off", "status")
        expect(
            Caffeination.until(start).status(until: "15:30") == "Caffeinated until 15:30",
            "a timed status names its end")
    }
}
