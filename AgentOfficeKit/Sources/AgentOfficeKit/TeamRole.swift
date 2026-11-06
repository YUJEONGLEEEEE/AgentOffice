import Foundation

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
        case .strategy: String(localized: "Strategy Team", bundle: .module)
        case .research: String(localized: "Research Team", bundle: .module)
        case .design: String(localized: "Design Team", bundle: .module)
        case .development: String(localized: "Development Team", bundle: .module)
        case .quality: String(localized: "Quality Team", bundle: .module)
        case .relations: String(localized: "Relations Team", bundle: .module)
        case .support: String(localized: "Support Team", bundle: .module)
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
    /// A short job title for name plates, for example "Researcher".
    public let title: String
    public let department: Department

    public init(agentType: String) {
        self.agentType = agentType
        switch agentType {
        case "contest-analyst": (title, department) = (String(localized: "Contest Analyst", bundle: .module), .strategy)
        case "service-planner": (title, department) = (String(localized: "Planner", bundle: .module), .strategy)
        case "market-researcher": (title, department) = (String(localized: "Researcher", bundle: .module), .research)
        case "data-analyst": (title, department) = (String(localized: "Data Analyst", bundle: .module), .research)
        case "ui-designer": (title, department) = (String(localized: "Designer", bundle: .module), .design)
        case "ios-developer": (title, department) = (String(localized: "iOS Developer", bundle: .module), .development)
        case "web-developer": (title, department) = (String(localized: "Web Developer", bundle: .module), .development)
        case "qa-reviewer": (title, department) = (String(localized: "QA Reviewer", bundle: .module), .quality)
        case "pitch-writer": (title, department) = (String(localized: "Pitch Writer", bundle: .module), .relations)
        case "Explore": (title, department) = (String(localized: "Explorer", bundle: .module), .support)
        case "Plan": (title, department) = (String(localized: "Architect", bundle: .module), .support)
        case "general-purpose": (title, department) = (String(localized: "Assistant", bundle: .module), .support)
        case "claude-code-guide": (title, department) = (String(localized: "Guide", bundle: .module), .support)
        default: (title, department) = (agentType, .support)
        }
    }
}
