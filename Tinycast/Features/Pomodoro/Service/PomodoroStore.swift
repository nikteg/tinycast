import Foundation

/// The cycle in progress, kept on disk so a relaunch or an update carries on where it was.
@MainActor
@Observable
final class PomodoroStore {
    /// Nil when stopped.
    private(set) var timer: PomodoroTimer?

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("pomodoro.json")) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else { return }
        timer = try? JSONDecoder().decode(PomodoroTimer.self, from: data)
    }

    func update(_ timer: PomodoroTimer?) {
        guard timer != self.timer else { return }
        self.timer = timer
        guard let timer, let data = try? JSONEncoder().encode(timer) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
