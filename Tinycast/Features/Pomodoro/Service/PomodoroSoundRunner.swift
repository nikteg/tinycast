import AppKit

/// Mater's original sounds: a wind-up as a phase starts, a click on pause, resume and stop, a ding.
@MainActor
final class PomodoroSoundRunner {
    enum Cue {
        case windUp
        case click
        case ding
    }

    private lazy var windUp = Self.sound("pomodoro-windup")
    private lazy var click = Self.sound("pomodoro-click")
    private lazy var ding = Self.sound("pomodoro-ding")

    func play(_ cue: Cue) {
        let sound =
            switch cue {
            case .windUp: windUp
            case .click: click
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
