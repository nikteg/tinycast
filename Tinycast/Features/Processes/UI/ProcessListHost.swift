import SwiftUI

/// Keeps the sweep running while a process screen shows, and the highlight on its row as rows change.
struct ProcessListHost: View {
    let session: ProcessSession
    let vm: PaletteState
    let rowIDs: [String]
    let content: AnyView

    private struct Snapshot: Equatable {
        let revision: Int
        let query: String
        let rowIDs: [String]
    }

    var body: some View {
        content
            // Keyed on visibility: ordering out leaves the tree mounted, and a hidden list needs no sweep.
            .task(id: vm.isVisible) {
                guard vm.isVisible else { return }
                await session.keepCurrent(excluding: ProcessCoordinator.ownPID)
            }
            .onChange(of: Snapshot(revision: session.revision, query: vm.query, rowIDs: rowIDs)) { old, new in
                // A new query lands the list itself; only a sweep or a quit moves rows under the reader.
                guard old.revision != new.revision, old.query == new.query else { return }
                vm.selection = RowFollowing.selection(vm.selection, from: old.rowIDs, to: new.rowIDs)
            }
    }
}
