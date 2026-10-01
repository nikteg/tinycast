import Foundation

/// The timers counting down, kept on disk so a relaunch or an update carries on where it was.
@MainActor
@Observable
final class TimerStore {
    private(set) var timers: [CountdownTimer] = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("timers.json")) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else { return }
        timers = (try? JSONDecoder().decode([CountdownTimer].self, from: data)) ?? []
    }

    func update(_ timers: [CountdownTimer]) {
        guard timers != self.timers else { return }
        self.timers = timers
        guard !timers.isEmpty, let data = try? JSONEncoder().encode(timers) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
