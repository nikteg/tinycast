import Foundation

/// Side-by-side apps with their own bundle ids, so a build updates within its own.
enum ReleaseChannel: Sendable {
    case stable
    case beta
    /// A local build. It has no release stream, and never updates itself.
    case development
    /// This fork's own build: it follows the fork's `main` rather than upstream's releases.
    case fork

    init(bundleID: String?) {
        switch bundleID {
        case "com.tinycast.app": self = .stable
        case "com.tinycast.app.beta": self = .beta
        case "com.tinycast.app.fork": self = .fork
        default: self = .development
        }
    }

    var updatesItself: Bool { self == .stable || self == .beta }

    /// Beta ships as a GitHub prerelease and stable does not; neither ever sees the other's.
    func accepts(prerelease: Bool) -> Bool {
        switch self {
        case .stable: return !prerelease
        case .beta: return prerelease
        case .development, .fork: return false
        }
    }
}
