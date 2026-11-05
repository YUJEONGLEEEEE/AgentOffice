import Foundation
import AgentOfficeKit

/// Reads the per-session event logs in a folder and builds the current state of each session.
struct SessionStore {

    /// Sessions whose last activity is older than this are hidden.
    static let visibleDuration: TimeInterval = 24 * 60 * 60
    /// The activity log keeps this many of the latest entries.
    static let activityLimit = 200

    struct Office {
        /// Working sessions first, then the most recently active.
        var sessions: [AgentSession] = []
        /// Latest first.
        var activity: [ActivityEntry] = []
    }

    let folderURL: URL

    func load(now: Date = .now) -> Office {
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var office = Office()
        for url in files where url.pathExtension == "jsonl" && isRecentlyModified(url, now: now) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let events = AgentEvent.parseLog(text)
            guard let session = AgentSession(events: events),
                  now.timeIntervalSince(session.lastActivity) < Self.visibleDuration else { continue }
            office.sessions.append(session)
            office.activity += AgentSession.activity(from: events)
        }

        office.sessions.sort { lhs, rhs in
            let lhsPresent = lhs.status(at: now) != .left
            let rhsPresent = rhs.status(at: now) != .left
            if lhsPresent != rhsPresent {
                return lhsPresent
            }
            return lhs.lastActivity > rhs.lastActivity
        }
        office.activity = Array(office.activity.sorted { $0.time > $1.time }.prefix(Self.activityLimit))
        return office
    }

    /// Skips old log files without reading them.
    private func isRecentlyModified(_ url: URL, now: Date) -> Bool {
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return true
        }
        return now.timeIntervalSince(modified) < Self.visibleDuration
    }
}
