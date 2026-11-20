import Foundation

@main
@MainActor
struct TimersTests {
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
        readsDurations()
        keepsTheLabel()
        rejectsWhatIsNoDuration()
        speaksAndCountsDown()
        runsPausesAndRestarts()
        ordersSoonestFirst()
        roundTripsThroughJSON()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func seconds(_ text: String) -> TimeInterval? {
        DurationPhrase.parse(text)?.seconds
    }

    static func readsDurations() {
        expect(seconds("25") == 25 * 60, "a bare number is minutes")
        expect(seconds("10m") == 600, "10m")
        expect(seconds("10 min") == 600, "a unit may be its own word")
        expect(seconds("2 hours") == 7200, "spelled-out units")
        expect(seconds("90s") == 90, "seconds")
        expect(seconds("1h30m") == 5400, "compact compound")
        expect(seconds("1h30") == 5400, "a unitless tail is the next unit down")
        expect(seconds("1m30") == 90, "minutes then seconds")
        expect(seconds("1.5h") == 5400, "fractions")
        expect(seconds("1 hour 30") == 5400, "words add up, a bare tail in minutes")
        expect(seconds("4:30") == 270, "m:ss")
        expect(seconds("1:04:30") == 3870, "h:mm:ss")
        expect(seconds("10M") == 600, "units ignore case")
    }

    static func keepsTheLabel() {
        let phrase = DurationPhrase.parse("10m tea")
        expect(phrase?.seconds == 600 && phrase?.label == "tea", "words after the length name it")
        let leading = DurationPhrase.parse("call mom in 5 min")
        expect(leading?.seconds == 300, "the length can come last")
        expect(leading?.label == "call mom in", "and the words before it are the name")
        expect(DurationPhrase.parse("25")?.label == "", "no words, no name")
    }

    static func rejectsWhatIsNoDuration() {
        expect(DurationPhrase.parse("") == nil, "empty")
        expect(DurationPhrase.parse("tea") == nil, "words alone")
        expect(DurationPhrase.parse("0") == nil, "zero")
        expect(DurationPhrase.parse("25h") == nil, "longer than a day")
        expect(DurationPhrase.parse("inf") == nil, "infinity is no length")
        expect(DurationPhrase.parse("4:75") == nil, "seconds past 59")
        expect(DurationPhrase.parse("10x")?.seconds == nil, "an unknown unit")
        expect(DurationPhrase.parse("10s5") == nil, "nothing below seconds")
    }

    static func speaksAndCountsDown() {
        expect(DurationText.spoken(600) == "10 minutes", "10 minutes")
        expect(DurationText.spoken(3600) == "1 hour", "singular")
        expect(DurationText.spoken(5430) == "1 hour 30 minutes 30 seconds", "every part")
        expect(DurationText.spoken(0) == "0 seconds", "nothing left")
        expect(DurationText.countdown(245) == "4:05", "m:ss")
        expect(DurationText.countdown(3870) == "1:04:30", "h:mm:ss")
        expect(DurationText.countdown(0.2) == "0:01", "never 0:00 while time is left")
        expect(DurationText.countdown(0) == "0:00", "0:00 when done")
    }

    static func runsPausesAndRestarts() {
        let phrase = DurationPhrase.parse("10m tea")!
        var timer = CountdownTimer.start(phrase, now: start)
        expect(timer.title == "tea", "a named timer is titled by its name")
        expect(CountdownTimer.start(DurationPhrase.parse("10m")!, now: start).title == "10 minutes",
               "an unnamed one by its length")
        expect(timer.endsAt == start + 600, "runs the full length")
        expect(!timer.hasEnded(now: start + 599), "not yet")
        expect(timer.hasEnded(now: start + 600), "ends on the second")

        timer.pause(now: start + 200)
        expect(!timer.isRunning && timer.remaining(now: start + 9999) == 400, "a paused clock stands")
        expect(!timer.hasEnded(now: start + 9999), "a paused timer never rings")
        timer.resume(now: start + 1000)
        expect(timer.endsAt == start + 1400, "resuming keeps what was left")
        timer.restart(now: start + 1100)
        expect(timer.endsAt == start + 1700, "restart is the full length again")
    }

    static func ordersSoonestFirst() {
        let long = CountdownTimer.start(DurationPhrase.parse("30m")!, now: start)
        let short = CountdownTimer.start(DurationPhrase.parse("5m")!, now: start)
        var paused = CountdownTimer.start(DurationPhrase.parse("1m")!, now: start)
        paused.pause(now: start)
        let ordered = CountdownTimer.ordered([paused, long, short])
        expect(ordered.map(\.id) == [short.id, long.id, paused.id], "running soonest first, paused last")
    }

    static func roundTripsThroughJSON() {
        var timer = CountdownTimer.start(DurationPhrase.parse("3m eggs")!, now: start)
        timer.pause(now: start + 30)
        let data = try? JSONEncoder().encode([timer])
        let decoded = data.flatMap { try? JSONDecoder().decode([CountdownTimer].self, from: $0) }
        expect(decoded == [timer], "a paused timer survives a relaunch as it was")
    }
}
