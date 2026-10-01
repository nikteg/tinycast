import SwiftUI

/// An app's helper wears its app's icon; anything else, a terminal.
struct ProcessIcon: View {
    let bundlePath: String?

    var body: some View {
        if let bundlePath {
            EntryIconView(source: .file(stamp: 0), fileURL: URL(fileURLWithPath: bundlePath))
        } else {
            EntryIconView(source: .symbol("terminal"))
        }
    }
}
