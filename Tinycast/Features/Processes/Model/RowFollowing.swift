import Foundation

/// Where the highlight goes when a sweep or a quit changes the rows under it.
enum RowFollowing {
    /// The same row where it still is; else the row that took its place, or the first of a fresh list.
    static func selection(_ selection: Int, from old: [String], to new: [String]) -> Int {
        guard old.indices.contains(selection) else { return 0 }
        if let index = new.firstIndex(of: old[selection]) { return index }
        return min(selection, max(new.count - 1, 0))
    }
}
