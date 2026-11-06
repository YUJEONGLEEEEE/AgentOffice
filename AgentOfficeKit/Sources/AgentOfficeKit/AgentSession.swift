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
    /// The project folder's ID from the latest event that had one.
    public private(set) var projectFolder: ProjectFolderID?
    public private(set) var room: Room = .desk
    public private(set) var lastActivity: Date
    /// Team members (subagents) that started and have not stopped yet, by agent ID.
    public private(set) var teamMembers: [String: TeamMember] = [:]

    /// IDs of subagents that started and have not stopped yet.
    public var activeSubagentIDs: Set<String> { Set(teamMembers.keys) }

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

    /// Shows the session on the floor of its project folder's current name.
    public mutating func renameProject(to name: String) {
        project = name
    }

    /// Updates the state with the next event.
    public mutating func apply(_ event: AgentEvent) {
        guard event.sessionID == id else { return }

        lastActivity = max(lastActivity, event.timestamp)
        if !event.project.isEmpty {
            project = event.project
        }
        if let folder = event.projectFolder {
            projectFolder = folder
        }

        // Subagents are tracked separately; they do not move the main agent.
        if event.isFromSubagent, event.kind == .preToolUse {
            applyTeamMemberTool(event)
            return
        }

        switch event.kind {
        case .sessionStart:
            recordedStatus = .arrived
            room = .desk
            teamMembers.removeAll()

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
            teamMembers.removeAll()

        case .subagentStart:
            // Internal helpers of Claude Code have no agent type; they are not team members.
            if let agentID = event.agentID, let agentType = event.agentType, !agentType.isEmpty {
                // New team members get their briefing in the meeting room first.
                teamMembers[agentID] = TeamMember(id: agentID, role: TeamRole(agentType: agentType),
                                                  room: .meetingRoom, status: .arrived, lastActivity: event.timestamp)
            }

        case .subagentStop:
            if let agentID = event.agentID {
                teamMembers[agentID] = nil
            }

        case .unknown:
            break
        }
    }

    /// A tool call from a team member moves that member, not the leader.
    private mutating func applyTeamMemberTool(_ event: AgentEvent) {
        guard let agentID = event.agentID else { return }
        if teamMembers[agentID] == nil {
            // The start event was missed, for example when the app was installed mid-task.
            guard let agentType = event.agentType, !agentType.isEmpty else { return }
            teamMembers[agentID] = TeamMember(id: agentID, role: TeamRole(agentType: agentType),
                                              room: .meetingRoom, status: .arrived, lastActivity: event.timestamp)
        }
        teamMembers[agentID]?.status = .working
        teamMembers[agentID]?.room = event.tool.map(Room.init(tool:)) ?? .desk
        teamMembers[agentID]?.lastActivity = event.timestamp
    }

    /// The status to show at the given time, applying the inactivity rule.
    public func status(at now: Date) -> AgentStatus {
        if now.timeIntervalSince(lastActivity) >= Self.inactivityLimit {
            return .left
        }
        return recordedStatus
    }
}

/// A team member (subagent) working for a session's leader.
public struct TeamMember: Identifiable, Equatable, Sendable {
    public let id: String
    public let role: TeamRole
    public var room: Room
    public var status: AgentStatus
    public var lastActivity: Date
}
