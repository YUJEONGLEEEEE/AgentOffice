/// The departments of the office team. Each department has its own uniform color.
public enum Department: String, CaseIterable, Sendable {
    case strategy
    case research
    case design
    case development
    case quality
    case relations
    /// Built-in helpers that are not part of a department, such as the Explore agent.
    case support

    public var displayName: String {
        switch self {
        case .strategy: "전략기획팀"
        case .research: "리서치팀"
        case .design: "디자인팀"
        case .development: "개발팀"
        case .quality: "품질관리팀"
        case .relations: "대외협력팀"
        case .support: "지원팀"
        }
    }

    /// Shirt color of everyone in the department.
    public var uniform: UInt32 {
        switch self {
        case .strategy: 0x2F5E8C
        case .research: 0x3E8E5E
        case .design: 0x7B5EA7
        case .development: 0xD9822B
        case .quality: 0xC0392B
        case .relations: 0x2A9D8F
        case .support: 0x8A8F98
        }
    }
}

/// The job of a team member (a subagent), read from its agent type, which is the `name` in its agent file.
public struct TeamRole: Equatable, Sendable {
    public let agentType: String
    /// A short job title for name plates, for example "리서처".
    public let title: String
    public let department: Department

    public init(agentType: String) {
        self.agentType = agentType
        switch agentType {
        case "contest-analyst": (title, department) = ("공고 분석가", .strategy)
        case "service-planner": (title, department) = ("기획자", .strategy)
        case "market-researcher": (title, department) = ("리서처", .research)
        case "data-analyst": (title, department) = ("데이터 분석가", .research)
        case "ui-designer": (title, department) = ("디자이너", .design)
        case "ios-developer": (title, department) = ("iOS 개발자", .development)
        case "web-developer": (title, department) = ("웹 개발자", .development)
        case "qa-reviewer": (title, department) = ("QA 검토자", .quality)
        case "pitch-writer": (title, department) = ("발표 담당", .relations)
        case "Explore": (title, department) = ("탐색 담당", .support)
        case "Plan": (title, department) = ("설계 담당", .support)
        case "general-purpose": (title, department) = ("지원 담당", .support)
        case "claude-code-guide": (title, department) = ("안내 담당", .support)
        default: (title, department) = (agentType, .support)
        }
    }
}
