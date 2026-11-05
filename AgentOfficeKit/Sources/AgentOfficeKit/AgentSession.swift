import Foundation

/// The current state of one Claude Code session, built by replaying its events in order.
///
/// All status rules live in `apply(_:)` and `status(at:)`, so later features
/// (such as automatic task assignment) can react to the same state.
public struct AgentSession: Identifiable, Equatable, Sendable {

    /// A session with no events for this long is treated as gone,
    /// for example when the terminal window was closed without `/exit`.
    public static let inactivityLimit: TimeInterval = 60 * 60

    public let id: String
    public private(set) var project: String
    public private(set) var room: Room = .desk
    public private(set) var lastActivity: Date
    /// IDs of subagents that started and have not stopped yet.
    public private(set) var activeSubagentIDs: Set<String> = []

    /// The status from the events alone, without the inactivity rule. Use `status(at:)` for display.
    public private(set) var recordedStatus: AgentStatus = .arrived

    /// Creates a session from its first event.
    public init(firstEvent event: AgentEvent) {
        id = event.sessionID
        project = event.project
        lastActivity = event.timestamp
        apply(event)
    }

    /// Creates a session by replaying events in order. Returns nil when there are no events.
    public init?(events: [AgentEvent]) {
        guard let first = events.first else { return nil }
        self.init(firstEvent: first)
        for event in events.dropFirst() {
            apply(event)
        }
    }

    /// Updates the state with the next event.
    public mutating func apply(_ event: AgentEvent) {
        guard event.sessionID == id else { return }

        lastActivity = max(lastActivity, event.timestamp)
        if !event.project.isEmpty {
            project = event.project
        }

        // Subagents are tracked separately; they do not move the main agent.
        if event.isFromSubagent, event.kind == .preToolUse {
            return
        }

        switch event.kind {
        case .sessionStart:
            recordedStatus = .arrived
            room = .desk
            activeSubagentIDs.removeAll()

        case .userPromptSubmit:
            recordedStatus = .received
            room = .desk

        case .preToolUse:
            recordedStatus = .working
            room = event.tool.map(Room.init(tool:)) ?? .desk

        case .notification:
            if event.notification == "permission_prompt" {
                recordedStatus = .waiting
            }

        case .stop:
            recordedStatus = .resting
            room = .breakRoom

        case .sessionEnd:
            recordedStatus = .left
            activeSubagentIDs.removeAll()

        case .subagentStart:
            if let agentID = event.agentID {
                activeSubagentIDs.insert(agentID)
            }

        case .subagentStop:
            if let agentID = event.agentID {
                activeSubagentIDs.remove(agentID)
            }

        case .unknown:
            break
        }
    }

    /// The status to show at the given time, applying the inactivity rule.
    public func status(at now: Date) -> AgentStatus {
        if now.timeIntervalSince(lastActivity) >= Self.inactivityLimit {
            return .left
        }
        return recordedStatus
    }
}
