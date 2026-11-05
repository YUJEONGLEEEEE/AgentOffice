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

    public init(id: String, name: String, floor: String, room: Room, status: AgentStatus, lastActivity: Date) {
        self.id = id
        self.name = name
        self.floor = floor
        self.room = room
        self.status = status
        self.lastActivity = lastActivity
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
}
