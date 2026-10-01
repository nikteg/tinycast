import ServiceManagement
import XPC

/// Tinycast's side of the root helper: its registration with launchd, and one request at a time.
@MainActor
final class PowerModeHelperClient {
    enum Readiness {
        case ready
        /// Registered, waiting on the reader in System Settings › Login Items.
        case needsApproval
        /// Registration refused — an unsigned build, or a bundle missing the job's plist.
        case unavailable
    }

    private let bundleID: String

    init(bundleID: String = Bundle.main.bundleIdentifier ?? "com.tinycast.app") {
        self.bundleID = bundleID
    }

    private var service: SMAppService {
        .daemon(plistName: PowerModeHelperMessage.plistName(forApp: bundleID))
    }

    /// Registers on first use, so the one step left to the reader is the approval.
    func prepare() -> Readiness {
        let service = service
        switch service.status {
        case .enabled:
            return .ready
        case .requiresApproval:
            return .needsApproval
        case .notRegistered, .notFound:
            // Registering a daemon that still needs approval throws, yet leaves it registered.
            try? service.register()
            switch service.status {
            case .enabled: return .ready
            case .requiresApproval: return .needsApproval
            default: return .unavailable
            }
        @unknown default:
            return .unavailable
        }
    }

    func openApproval() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setBattery(_ mode: PowerMode) async -> Bool {
        let label = PowerModeHelperMessage.label(forApp: bundleID)
        return await Task.detached { Self.send(mode, to: label) }.value
    }

    /// Blocks its thread until the helper answers, which is why it only runs detached.
    nonisolated private static func send(_ mode: PowerMode, to label: String) -> Bool {
        guard let session = try? XPCSession(machService: label, options: .privileged) else {
            return false
        }
        defer { session.cancel(reason: "Done") }
        let reply: PowerModeHelperMessage.Reply? = try? session.sendSync(
            PowerModeHelperMessage.Request(mode: mode))
        return reply?.succeeded ?? false
    }
}
