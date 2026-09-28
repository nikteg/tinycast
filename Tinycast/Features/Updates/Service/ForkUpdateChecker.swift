import Foundation

/// The fork's daily check against its own `main`. See FORK.md.
@MainActor
final class ForkUpdateChecker {
    enum Outcome: Equatable {
        case upToDate
        case available(ForkUpdate)
        /// Built from a commit GitHub does not have, so there is nothing to compare with.
        case unpublished
        /// Built without `mise run install`, so it never recorded its commit.
        case unknownBuild
        case failed
    }

    private static let refreshInterval: TimeInterval = 24 * 3600
    private static let retryInterval: TimeInterval = 2 * 3600
    /// A withheld prompt is re-offered this often, this many times, then left to the daily check.
    private static let withheldInterval: TimeInterval = 120
    private static let withheldRetryLimit = 15
    private static let startupDelay = Duration.seconds(30)

    /// Stamped into Info.plist by the mise build, and empty in any other build.
    let sourceCommit: String?
    let sourcePath: String?

    /// Raised on an unskipped update; `false` answers that the prompt was withheld and is owed.
    var onUpdateAvailable: (@MainActor (ForkUpdate) -> Bool)?

    private let fileURL: URL
    private var latest: ForkUpdate?
    private var lastCheckedAt: Date?
    private var skippedHead: String?
    private var announcedHead: String?
    private var withheldRetries = 0
    private var pump: Task<Void, Never>?

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        sourceCommit = (info["TinycastSourceCommit"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        sourcePath = (info["TinycastSourcePath"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        fileURL = AppPaths.caches().appendingPathComponent("fork-update-check.json")
        // A cache written by another build compared a different commit, so none of it holds.
        guard let data = try? Data(contentsOf: fileURL),
            let cache = try? JSONDecoder().decode(Cache.self, from: data),
            cache.builtFrom == sourceCommit
        else { return }
        latest = cache.latest
        lastCheckedAt = cache.lastCheckedAt
        skippedHead = cache.skippedHead
    }

    deinit { pump?.cancel() }

    func start() {
        guard sourceCommit != nil else { return }
        pump?.cancel()
        pump = Task { [weak self] in
            try? await Task.sleep(for: Self.startupDelay)
            while !Task.isCancelled {
                guard let wait = await self?.advance() else { return }
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    /// The manual path: ignores freshness and the skipped head.
    func check() async -> Outcome {
        guard let sourceCommit, let url = ForkFeed.endpoint(comparing: sourceCommit) else {
            return .unknownBuild
        }
        let (data, status) = await Self.body(url)
        if status == 404 { return .unpublished }
        guard let data, let answer = ForkFeed.status(from: data) else { return .failed }
        lastCheckedAt = Date()
        switch answer {
        case .upToDate: latest = nil
        case .available(let update): latest = update
        }
        persist()
        return latest.map(Outcome.available) ?? .upToDate
    }

    /// Later is a skip: this head stops asking, and a newer push asks again.
    func skip(_ update: ForkUpdate) {
        skippedHead = update.head
        persist()
    }

    private func advance() async -> TimeInterval {
        let age = max(0, lastCheckedAt.map { Date().timeIntervalSince($0) } ?? .infinity)
        var wait = Self.refreshInterval - age
        if wait <= 0 {
            switch await check() {
            case .upToDate, .available, .unpublished: wait = Self.refreshInterval
            case .failed, .unknownBuild: wait = Self.retryInterval
            }
        }
        if announce() {
            withheldRetries = 0
        } else if withheldRetries < Self.withheldRetryLimit {
            withheldRetries += 1
            wait = min(wait, Self.withheldInterval)
        }
        return wait
    }

    private func announce() -> Bool {
        guard let latest, latest.head != skippedHead, latest.head != announcedHead else { return true }
        guard onUpdateAvailable?(latest) ?? true else { return false }
        announcedHead = latest.head
        return true
    }

    private func persist() {
        let cache = Cache(
            builtFrom: sourceCommit, lastCheckedAt: lastCheckedAt, latest: latest, skippedHead: skippedHead)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private struct Cache: Codable {
        var builtFrom: String?
        var lastCheckedAt: Date?
        var latest: ForkUpdate?
        var skippedHead: String?
    }

    /// Cacheless, never `URLSession.shared`, so the snapshot on disk stays the only copy.
    private nonisolated static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private nonisolated static func body(_ url: URL) async -> (Data?, Int?) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        // GitHub rejects an API request carrying no User-Agent outright.
        request.setValue("Tinycast", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        guard let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse
        else { return (nil, nil) }
        return (http.statusCode == 200 ? data : nil, http.statusCode)
    }
}
