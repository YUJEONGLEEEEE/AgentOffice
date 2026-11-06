import Foundation

/// One line of an event log written by the Claude Code hook script.
///
/// Example line:
/// `{"ts":"2026-11-05T07:10:12Z","event":"PreToolUse","session":"e77b…","project":"AgentOffice","tool":"Bash"}`
public struct AgentEvent: Codable, Equatable, Sendable {

    public enum Kind: String, Codable, Sendable {
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case userPromptSubmit = "UserPromptSubmit"
        case preToolUse = "PreToolUse"
        case subagentStart = "SubagentStart"
        case subagentStop = "SubagentStop"
        case notification = "Notification"
        case stop = "Stop"
        /// An event this version of the app does not know yet.
        case unknown

        public init(from decoder: Decoder) throws {
            let rawValue = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: rawValue) ?? .unknown
        }
    }

    public let timestamp: Date
    public let kind: Kind
    public let sessionID: String
    public let project: String
    public let tool: String?
    public let agentID: String?
    public let agentType: String?
    public let notification: String?
    /// The project folder's volume and file number, so the app can follow a rename or notice a deletion.
    /// Older logs do not have them.
    public let projectFolder: ProjectFolderID?

    public init(
        timestamp: Date,
        kind: Kind,
        sessionID: String,
        project: String,
        tool: String? = nil,
        agentID: String? = nil,
        agentType: String? = nil,
        notification: String? = nil,
        projectFolder: ProjectFolderID? = nil
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.sessionID = sessionID
        self.project = project
        self.tool = tool
        self.agentID = agentID
        self.agentType = agentType
        self.notification = notification
        self.projectFolder = projectFolder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        kind = try container.decode(Kind.self, forKey: .kind)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        project = try container.decode(String.self, forKey: .project)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        agentID = try container.decodeIfPresent(String.self, forKey: .agentID)
        agentType = try container.decodeIfPresent(String.self, forKey: .agentType)
        notification = try container.decodeIfPresent(String.self, forKey: .notification)
        // A broken folder ID must not hide the event.
        if let device = try? container.decodeIfPresent(Int32.self, forKey: .projectDevice),
           let inode = try? container.decodeIfPresent(UInt64.self, forKey: .projectInode) {
            projectFolder = ProjectFolderID(device: device, inode: inode)
        } else {
            projectFolder = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(project, forKey: .project)
        try container.encodeIfPresent(tool, forKey: .tool)
        try container.encodeIfPresent(agentID, forKey: .agentID)
        try container.encodeIfPresent(agentType, forKey: .agentType)
        try container.encodeIfPresent(notification, forKey: .notification)
        try container.encodeIfPresent(projectFolder?.device, forKey: .projectDevice)
        try container.encodeIfPresent(projectFolder?.inode, forKey: .projectInode)
    }

    /// True when the event came from a subagent rather than the main session agent.
    public var isFromSubagent: Bool {
        agentID != nil
    }

    private enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case kind = "event"
        case sessionID = "session"
        case project
        case tool
        case agentID = "agentId"
        case agentType
        case notification
        case projectDevice
        case projectInode
    }
}

extension AgentEvent {

    /// Parses a JSON Lines log. Lines that cannot be decoded are skipped,
    /// so one broken line never hides the rest of the log.
    public static func parseLog(_ text: String) -> [AgentEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return text
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                try? decoder.decode(AgentEvent.self, from: Data(line.utf8))
            }
    }
}
