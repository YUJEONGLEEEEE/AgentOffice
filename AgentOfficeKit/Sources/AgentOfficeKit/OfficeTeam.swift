import Foundation

/// The team that works in the office every day: nine members with their own desks.
///
/// Team members are always in the office. When a leader gives one of them work,
/// that member leaves their desk and works; when the work is done they go back to their desk.
public enum OfficeTeam {

    /// Everyone on the team, in the order of the departments.
    public static let roster: [TeamRole] = [
        "contest-analyst", "service-planner",
        "market-researcher", "data-analyst",
        "ui-designer",
        "ios-developer", "web-developer",
        "qa-reviewer",
        "pitch-writer",
    ].map(TeamRole.init(agentType:))

    /// The ID of a team member's character, which stays the same between tasks.
    public static func residentID(for agentType: String) -> String {
        "team.\(agentType)"
    }

    /// Adds the team to the agents from the event logs.
    ///
    /// - A team member with no work waits at their desk (`idle`).
    /// - A team member with work shows that work, under their own ID, so the same character walks
    ///   from the desk to the work and back.
    /// - If the same member has several jobs at once, the extra jobs appear as extra characters.
    /// - Built-in helpers that are not on the team (such as the Explore agent) come and go as before.
    public static func arrange(_ agents: [AgentSnapshot]) -> [AgentSnapshot] {
        let rosterTypes = Set(roster.map(\.agentType))
        var result = agents.filter { agent in
            guard let role = agent.role else { return true }
            return !rosterTypes.contains(role)
        }

        for role in roster {
            let jobs = agents
                .filter { $0.role == role.agentType && $0.status != .left }
                .sorted { $0.lastActivity > $1.lastActivity }

            if let current = jobs.first {
                result.append(AgentSnapshot(
                    id: residentID(for: role.agentType), name: current.name, floor: current.floor,
                    room: current.room, status: current.status, lastActivity: current.lastActivity,
                    role: role.agentType
                ))
                result += jobs.dropFirst()
            } else {
                result.append(AgentSnapshot(
                    id: residentID(for: role.agentType), name: "", floor: "",
                    room: OfficeLayout.standard.seat(forAgentType: role.agentType)?.room ?? .desk,
                    status: .idle, lastActivity: .distantPast, role: role.agentType
                ))
            }
        }
        return result
    }
}
