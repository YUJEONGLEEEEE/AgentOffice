/// What an agent is doing right now.
public enum AgentStatus: String, CaseIterable, Sendable {
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

    public var displayName: String {
        switch self {
        case .arrived: "출근함"
        case .received: "일 받음"
        case .working: "일하는 중"
        case .waiting: "기다리는 중"
        case .resting: "쉬는 중"
        case .left: "퇴근"
        }
    }
}
