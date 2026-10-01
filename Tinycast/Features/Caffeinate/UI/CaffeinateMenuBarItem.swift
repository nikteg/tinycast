import SwiftUI

/// Reading the coordinator here scopes Observation to this label, not to every scene.
struct CaffeinateMenuBarLabel: View {
    let appName: String

    private var coordinator: CaffeinateCoordinator { AppCore.shared.caffeinateCoordinator }

    var body: some View {
        Image(systemName: "cup.and.heat.waves.fill")
            .accessibilityLabel("\(appName): \(coordinator.status ?? "Caffeinated")")
    }
}

struct CaffeinateMenuBarMenu: View {
    private var coordinator: CaffeinateCoordinator { AppCore.shared.caffeinateCoordinator }

    var body: some View {
        if let status = coordinator.status {
            Text(status)
            Divider()
        }
        Button("Decaffeinate") { coordinator.decaffeinate() }
        Button("Caffeinate for Duration…") { coordinator.showDurations() }
    }
}
