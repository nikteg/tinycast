import Foundation

/// Every colour picked, newest first, kept on disk so the history survives a relaunch.
@MainActor
@Observable
final class ColorHistoryStore {
    private(set) var colors: [PickedColor] = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("colors.json")) {
        self.fileURL = fileURL
        guard let data = try? Data(contentsOf: fileURL) else { return }
        colors = (try? JSONDecoder().decode([PickedColor].self, from: data)) ?? []
    }

    func add(_ color: PickedColor) {
        save(ColorHistory.adding(color, to: colors))
    }

    func remove(_ color: PickedColor) {
        save(colors.filter { $0.id != color.id })
    }

    func removeAll() {
        save([])
    }

    private func save(_ colors: [PickedColor]) {
        self.colors = colors
        guard !colors.isEmpty, let data = try? JSONEncoder().encode(colors) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
