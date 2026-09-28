import AppKit

/// Mater v2.0.3's wind-up as a phase starts; its current toggles on pause and resume, and ding.
@MainActor
final class PomodoroSoundRunner {
    enum Cue {
        case windUp
        case toggleOn
        case toggleOff
        case ding
    }

    private lazy var windUp = Self.sound("pomodoro-windup")
    private lazy var toggleOn = Self.sound("pomodoro-toggle-on")
    private lazy var toggleOff = Self.sound("pomodoro-toggle-off")
    private lazy var ding = Self.sound("pomodoro-ding")

    func play(_ cue: Cue) {
        let sound =
            switch cue {
            case .windUp: windUp
            case .toggleOn: toggleOn
            case .toggleOff: toggleOff
            case .ding: ding
            }
        sound?.stop()
        sound?.play()
    }

    func stopWindUp() {
        windUp?.stop()
    }

    private static func sound(_ name: String) -> NSSound? {
        Bundle.main.url(forResource: name, withExtension: "wav").flatMap {
            NSSound(contentsOf: $0, byReference: false)
        }
    }
}
