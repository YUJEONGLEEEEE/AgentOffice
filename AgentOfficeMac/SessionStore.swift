import Foundation
import AgentOfficeKit

/// Reads the per-session event logs in a folder and builds the current state of each session.
struct SessionStore {

    /// Sessions whose last activity is older than this are hidden from the list.
    static let visibleDuration: TimeInterval = 24 * 60 * 60

    let folderURL: URL

    /// Working sessions first, then the most recently active.
    func loadSessions(now: Date = .now) -> [AgentSession] {
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return files
            .filter { $0.pathExtension == "jsonl" }
            .filter { isRecentlyModified($0, now: now) }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                return AgentSession(events: AgentEvent.parseLog(text))
            }
            .filter { now.timeIntervalSince($0.lastActivity) < Self.visibleDuration }
            .sorted { lhs, rhs in
                let lhsPresent = lhs.status(at: now) != .left
                let rhsPresent = rhs.status(at: now) != .left
                if lhsPresent != rhsPresent {
                    return lhsPresent
                }
                return lhs.lastActivity > rhs.lastActivity
            }
    }

    /// Skips old log files without reading them.
    private func isRecentlyModified(_ url: URL, now: Date) -> Bool {
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return true
        }
        return now.timeIntervalSince(modified) < Self.visibleDuration
    }
}
