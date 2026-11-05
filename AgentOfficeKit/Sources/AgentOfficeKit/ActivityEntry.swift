import Foundation

/// One line of the activity log: an agent moved to another room or its status changed.
///
/// Like `AgentSnapshot`, it only holds a summary. Prompts, code, commands and paths are never part of it.
public struct ActivityEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let time: Date
    public let agentID: String
    public let agentName: String
    public let floor: String
    public let room: Room
    public let status: AgentStatus

    public init(id: String, time: Date, agentID: String, agentName: String, floor: String, room: Room, status: AgentStatus) {
        self.id = id
        self.time = time
        self.agentID = agentID
        self.agentName = agentName
        self.floor = floor
        self.room = room
        self.status = status
    }

    /// A short sentence for the log, for example "서버실에서 일하는 중".
    public var summary: String {
        switch status {
        case .arrived: "출근했어요"
        case .received: "새 일을 받았어요"
        case .working: "\(room.displayName)에서 일하는 중"
        case .waiting: "허락을 기다리는 중"
        case .resting: room == .breakRoom ? "탕비실에서 커피 마시는 중" : "쉬는 중"
        case .left: "퇴근했어요"
        }
    }
}

extension AgentSession {

    /// Replays a session's events and keeps one entry each time the room or status changes.
    /// Several tools in a row in the same room count as one entry, so the log stays short.
    public static func activity(from events: [AgentEvent]) -> [ActivityEntry] {
        var session: AgentSession?
        var entries: [ActivityEntry] = []

        for event in events {
            let before = session.map { ($0.room, $0.recordedStatus) }
            if session == nil {
                session = AgentSession(firstEvent: event)
            } else {
                session?.apply(event)
            }
            guard let current = session, event.sessionID == current.id else { continue }
            if let before, before == (current.room, current.recordedStatus) {
                continue
            }
            entries.append(ActivityEntry(
                id: "\(current.id)-\(entries.count)",
                time: event.timestamp,
                agentID: current.id,
                agentName: String(current.id.prefix(4)),
                floor: current.project,
                room: current.room,
                status: current.recordedStatus
            ))
        }
        return entries
    }
}
