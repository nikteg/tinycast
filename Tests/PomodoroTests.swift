import Foundation

@main
@MainActor
struct PomodoroTests {
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
        followsMatersPattern()
        pausesAndResumes()
        skipsToTheNextPhase()
        catchesUpAfterSleep()
        clampsDurations()
        announcesEachChange()
        roundTripsThroughJSON()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let standard = PomodoroDurations.standard

    static func followsMatersPattern() {
        expect(standard.workMinutes == 25 && standard.restMinutes == 5, "25 minutes of work, 5 of rest")
        var timer = PomodoroTimer.start(now: start, durations: standard)
        expect(timer.phase == .work, "a cycle opens on work")
        expect(timer.endsAt == start + 25 * 60, "work runs 25 minutes")
        expect(timer.minutesLeft(now: start + 1) == 25, "24:59 left still reads 25, as Mater counts")
        expect(timer.minutesLeft(now: start + 60) == 24, "a whole minute gone reads 24")

        expect(timer.advance(now: start + 25 * 60 - 1, durations: standard) == nil, "no change before the end")
        expect(timer.advance(now: start + 25 * 60, durations: standard) == .rest, "work gives way to rest")
        expect(timer.endsAt == start + 30 * 60, "rest runs 5 minutes from where work ended")
        expect(timer.advance(now: start + 30 * 60, durations: standard) == .work, "rest gives way to work")
        expect(timer.endsAt == start + 55 * 60, "and work runs its 25 again")
    }

    static func pausesAndResumes() {
        var timer = PomodoroTimer.start(now: start, durations: standard)
        timer.pause(now: start + 10 * 60)
        expect(!timer.isRunning, "paused is not running")
        expect(timer.remaining(now: start + 99 * 60) == 15 * 60, "a paused clock does not move")
        expect(timer.advance(now: start + 99 * 60, durations: standard) == nil, "a paused phase never ends")
        timer.resume(now: start + 60 * 60)
        expect(timer.endsAt == start + 75 * 60, "resuming keeps the 15 minutes that were left")
    }

    static func skipsToTheNextPhase() {
        var timer = PomodoroTimer.start(now: start, durations: standard)
        timer.skip(now: start + 60, durations: standard)
        expect(timer.phase == .rest && timer.endsAt == start + 6 * 60, "skipping opens a full rest")
        timer.pause(now: start + 2 * 60)
        timer.skip(now: start + 3 * 60, durations: standard)
        expect(timer.phase == .work && timer.remaining(now: start) == 25 * 60, "a paused skip stays paused")
    }

    static func catchesUpAfterSleep() {
        var timer = PomodoroTimer.start(now: start, durations: standard)
        // 25 work + 5 rest + 25 work + 5 rest = 60 minutes; 62 lands 2 minutes into work.
        expect(timer.advance(now: start + 62 * 60, durations: standard) == .work, "lands where the clock is")
        expect(timer.endsAt == start + 85 * 60, "on the schedule it would have kept awake")
    }

    static func clampsDurations() {
        let wide = PomodoroDurations(workMinutes: 0, restMinutes: 90)
        expect(wide.workMinutes == 1 && wide.restMinutes == 30, "durations clamp to Mater's ranges")
    }

    static func announcesEachChange() {
        let rest = PomodoroAnnouncement.entering(.rest, durations: standard, until: "10:55")
        expect(rest.title == "Time for a break", "entering rest says so")
        expect(rest.body == "Take 5 minutes off, until 10:55.", "and says for how long")
        let work = PomodoroAnnouncement.entering(
            .work, durations: PomodoroDurations(workMinutes: 1, restMinutes: 5), until: "11:20")
        expect(work.title == "Break's over", "entering work says so")
        expect(work.body == "Back to work for 1 minute, until 11:20.", "with a singular minute")
    }

    static func roundTripsThroughJSON() {
        var timer = PomodoroTimer.start(now: start, durations: standard)
        timer.pause(now: start + 90)
        let data = try? JSONEncoder().encode(timer)
        let decoded = data.flatMap { try? JSONDecoder().decode(PomodoroTimer.self, from: $0) }
        expect(decoded == timer, "a paused cycle survives a relaunch")
    }
}
