import Foundation

/// Commits on the fork's `main` that a build lacks, reduced to what the prompt shows.
struct ForkUpdate: Codable, Hashable, Sendable {
    /// The newest commit on `main`, which is what Later skips.
    let head: String
    let aheadBy: Int
    /// First lines, newest first.
    let subjects: [String]
    let compareURL: URL
}

/// The fork publishes no releases: an update is `main` moving past the commit a build was made from.
enum ForkFeed {
    static let repository = "nikteg/tinycast"
    static let branch = "main"
    static let updateCommand = "git pull && mise run install"

    enum Status: Equatable, Sendable {
        case upToDate
        case available(ForkUpdate)
    }

    static func endpoint(comparing commit: String) -> URL? {
        guard commit.allSatisfy(\.isHexDigit), !commit.isEmpty else { return nil }
        return URL(string: "https://api.github.com/repos/\(repository)/compare/\(commit)...\(branch)")
    }

    /// Nil for an unreadable body; commits the build has that `main` lacks are not an update.
    static func status(from data: Data) -> Status? {
        guard let body = try? JSONDecoder().decode(Compare.self, from: data) else { return nil }
        guard body.aheadBy > 0, let head = body.commits.last?.sha else { return .upToDate }
        return .available(
            ForkUpdate(
                head: head, aheadBy: body.aheadBy,
                subjects: body.commits.reversed().map { subject(of: $0.commit.message) },
                compareURL: body.htmlURL))
    }

    /// What to paste into a terminal: into the clone the build came from, when it is known.
    static func command(sourcePath: String?) -> String {
        guard let sourcePath, !sourcePath.isEmpty else { return updateCommand }
        let quoted = "'" + sourcePath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "cd \(quoted) && \(updateCommand)"
    }

    private static func subject(of message: String) -> String {
        String(message.prefix { $0 != "\n" }).trimmingCharacters(in: .whitespaces)
    }

    private struct Compare: Decodable {
        let aheadBy: Int
        let htmlURL: URL
        let commits: [Commit]

        enum CodingKeys: String, CodingKey {
            case aheadBy = "ahead_by"
            case htmlURL = "html_url"
            case commits
        }

        struct Commit: Decodable {
            let sha: String
            let commit: Detail

            struct Detail: Decodable {
                let message: String
            }
        }
    }
}
