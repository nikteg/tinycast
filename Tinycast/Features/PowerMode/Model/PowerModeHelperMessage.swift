import Foundation

/// What Tinycast asks its root helper, and how each channel names the helper's launchd job.
enum PowerModeHelperMessage {
    struct Request: Codable, Sendable {
        let mode: PowerMode
    }

    struct Reply: Codable, Sendable {
        let succeeded: Bool
    }

    /// The job's label and Mach service, keyed by the app's bundle id so channels never share one.
    static func label(forApp bundleID: String) -> String { bundleID + ".power-mode" }

    static func plistName(forApp bundleID: String) -> String { label(forApp: bundleID) + ".plist" }
}
