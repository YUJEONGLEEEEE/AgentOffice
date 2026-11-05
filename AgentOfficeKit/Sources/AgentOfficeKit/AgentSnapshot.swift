import Foundation

/// A small summary of one agent: everything the office needs to draw it, and nothing more.
///
/// This is the only data the office scene receives. It is also the shape of the data
/// that will later be synced to iPhone, so it must never carry prompts, code, commands or paths.
public struct AgentSnapshot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    /// A short display name, for example the first characters of the session ID.
    public let name: String
    /// The project folder name. Each project is one floor of the office.
    public let floor: String
    public let room: Room
    public let status: AgentStatus
    public let lastActivity: Date
    /// The team member's agent type, such as "market-researcher". `nil` for a team leader (the main session).
    public let role: String?

    public init(id: String, name: String, floor: String, room: Room, status: AgentStatus, lastActivity: Date, role: String? = nil) {
        self.id = id
        self.name = name
        self.floor = floor
        self.room = room
        self.status = status
        self.lastActivity = lastActivity
        self.role = role
    }
}

extension AgentSession {

    /// The summary of this session at the given time.
    public func snapshot(at now: Date) -> AgentSnapshot {
        AgentSnapshot(
            id: id,
            name: String(id.prefix(4)),
            floor: project,
            room: room,
            status: status(at: now),
            lastActivity: lastActivity
        )
    }

    /// The leader and, while the leader is in the office, every team member.
    /// Team members are named after their job and their leader, for example "리서처 · eebe".
    public func snapshots(at now: Date) -> [AgentSnapshot] {
        let leader = snapshot(at: now)
        guard leader.status != .left else { return [leader] }
        let members = teamMembers.values.sorted { $0.id < $1.id }.map { member in
            AgentSnapshot(
                id: "\(id).\(member.id)",
                name: "\(member.role.title) · \(leader.name)",
                floor: project,
                room: member.room,
                status: member.status,
                lastActivity: member.lastActivity,
                role: member.role.agentType
            )
        }
        return [leader] + members
    }
}
