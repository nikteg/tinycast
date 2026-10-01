import Foundation
import XPC

/// Root's half of Toggle Low Power Mode: sets the battery's Energy Mode, and nothing else.
@main
nonisolated enum PowerModeHelper {
    static func main() {
        // launchd passes the app's bundle id, which names the service and is the only peer allowed.
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let app = CommandLine.arguments[1]
        var facts = XPCDictionary()
        facts["signing-identifier"] = app
        do {
            let listener = try XPCListener(
                service: PowerModeHelperMessage.label(forApp: app),
                requirement: XPCPeerRequirement(lightweightCodeRequirements: facts)
            ) { request in
                request.accept { (message: PowerModeHelperMessage.Request) in
                    PowerModeHelperMessage.Reply(succeeded: setBattery(message.mode))
                }
            }
            withExtendedLifetime(listener) { dispatchMain() }
        } catch {
            exit(1)
        }
    }

    private static func setBattery(_ mode: PowerMode) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-b", "powermode", String(mode.rawValue)]
        guard let exit = try? process.runObservingExit() else { return false }
        exit.wait()
        return process.terminationStatus == 0
    }
}
