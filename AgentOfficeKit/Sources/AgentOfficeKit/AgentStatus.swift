/// What an agent is doing right now.
public enum AgentStatus: String, CaseIterable, Codable, Sendable {
    /// The session just started.
    case arrived
    /// The user sent a prompt and the agent is about to start.
    case received
    /// The agent is using a tool.
    case working
    /// The agent is waiting for the user to approve a permission.
    case waiting
    /// The agent finished its reply and is waiting for the next prompt.
    case resting
    /// The session ended, or there has been no activity for too long.
    case left
    /// A team member sitting at their own desk with nothing to do.
    case idle

    public var displayName: String {
        switch self {
        case .arrived: "출근함"
        case .received: "일 받음"
        case .working: "일하는 중"
        case .waiting: "기다리는 중"
        case .resting: "쉬는 중"
        case .left: "퇴근"
        case .idle: "대기 중"
        }
    }
}

extension AgentStatus {

    /// Background color of the status tag, shared by the office scene and the app's cards.
    public var tagColor: UInt32 {
        switch self {
        case .working: 0xF2B33D
        case .waiting: 0xE8684A
        case .resting: 0xBFE3C8
        case .arrived, .received: 0xBFD7F5
        case .left: 0xC9C0B0
        case .idle: 0xDDE3EA
        }
    }

    /// Text color on top of `tagColor`.
    public var tagTextColor: UInt32 {
        switch self {
        case .working, .left, .idle: 0x2E2A35
        case .waiting: 0x1F1C24
        case .resting: 0x1F3A28
        case .arrived, .received: 0x1E3350
        }
    }
}
