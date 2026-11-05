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

    /// Replays a session's events and keeps one entry each time someone's room or status changes:
    /// the leader, or a team member joining, moving or finishing.
    /// Several tools in a row in the same room count as one entry, so the log stays short.
    public static func activity(from events: [AgentEvent]) -> [ActivityEntry] {
        var session: AgentSession?
        var entries: [ActivityEntry] = []
        var previous: [String: (name: String, room: Room, status: AgentStatus)] = [:]

        for event in events {
            if session == nil {
                session = AgentSession(firstEvent: event)
            } else {
                session?.apply(event)
            }
            guard let current = session, event.sessionID == current.id else { continue }

            let leaderName = String(current.id.prefix(4))
            var people: [String: (name: String, room: Room, status: AgentStatus)] = [
                current.id: (leaderName, current.room, current.recordedStatus),
            ]
            for member in current.teamMembers.values {
                people["\(current.id).\(member.id)"] = ("\(member.role.title) · \(leaderName)", member.room, member.status)
            }

            func record(_ personID: String, _ state: (name: String, room: Room, status: AgentStatus)) {
                entries.append(ActivityEntry(
                    id: "\(current.id)-\(entries.count)",
                    time: event.timestamp,
                    agentID: personID,
                    agentName: state.name,
                    floor: current.project,
                    room: state.room,
                    status: state.status
                ))
            }

            for (personID, state) in people.sorted(by: { $0.key < $1.key }) {
                if let before = previous[personID], before.room == state.room, before.status == state.status {
                    continue
                }
                record(personID, state)
            }
            // Team members who finished go home.
            for (personID, state) in previous.sorted(by: { $0.key < $1.key }) where people[personID] == nil {
                record(personID, (state.name, state.room, .left))
            }
            previous = people
        }
        return entries
    }
}
