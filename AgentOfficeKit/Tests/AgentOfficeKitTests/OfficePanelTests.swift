import Foundation
import Testing
@testable import AgentOfficeKit

struct FloorSummaryTests {

    private let now = Date(timeIntervalSince1970: 1_793_862_600)

    private func agent(_ id: String, floor: String, status: AgentStatus, minutesAgo: Double) -> AgentSnapshot {
        AgentSnapshot(id: id, name: String(id.prefix(4)), floor: floor, room: .desk, status: status,
                      lastActivity: now.addingTimeInterval(-minutesAgo * 60))
    }

    @Test func countsPresentAgentsPerFloor() {
        let floors = FloorSummary.floors(from: [
            agent("a1", floor: "Blog", status: .working, minutesAgo: 1),
            agent("a2", floor: "Blog", status: .left, minutesAgo: 90),
            agent("b1", floor: "AgentOffice", status: .resting, minutesAgo: 5),
        ])

        #expect(floors.map(\.name) == ["AgentOffice", "Blog"])
        #expect(floors.map(\.presentCount) == [1, 1])
    }

    @Test func keepsNameOrder() {
        let floors = FloorSummary.floors(from: [
            agent("a1", floor: "Zoo", status: .working, minutesAgo: 1),
            agent("b1", floor: "Apple", status: .working, minutesAgo: 30),
        ])

        #expect(floors.map(\.name) == ["Apple", "Zoo"])
    }
}

struct ActivityEntryTests {

    private let start = Date(timeIntervalSince1970: 1_793_862_600)

    private func events(_ items: [(AgentEvent.Kind, String?)], agentID: String? = nil) -> [AgentEvent] {
        items.enumerated().map { index, item in
            AgentEvent(timestamp: start.addingTimeInterval(TimeInterval(index)), kind: item.0,
                       sessionID: "eebe4d02", project: "AgentOffice", tool: item.1)
        }
    }

    @Test func recordsOnlyChanges() {
        let entries = AgentSession.activity(from: events([
            (.sessionStart, nil), (.userPromptSubmit, nil),
            (.preToolUse, "Bash"), (.preToolUse, "Bash"), (.preToolUse, "Read"), (.preToolUse, "Grep"),
            (.stop, nil),
        ]))

        #expect(entries.map(\.status) == [.arrived, .received, .working, .working, .resting])
        #expect(entries.map(\.room) == [.desk, .desk, .serverRoom, .archive, .breakRoom])
        #expect(entries.map(\.summary).last == "탕비실에서 커피 마시는 중")
        #expect(Set(entries.map(\.id)).count == entries.count)
    }

    @Test func ignoresSubagentTools() {
        var list = events([(.preToolUse, "Bash")])
        list.append(AgentEvent(timestamp: start.addingTimeInterval(5), kind: .preToolUse, sessionID: "eebe4d02",
                               project: "AgentOffice", tool: "Read", agentID: "helper"))

        #expect(AgentSession.activity(from: list).count == 1)
    }

    @Test func summarySaysWhereTheAgentWorks() {
        let entry = ActivityEntry(id: "x", time: start, agentID: "eebe", agentName: "eebe", floor: "AgentOffice",
                                  room: .serverRoom, status: .working)

        #expect(entry.summary == "서버실에서 일하는 중")
    }
}

struct AgentPortraitTests {

    @Test func drawsTwelveBySixteenPixels() throws {
        let image = try #require(AgentPortrait.image(forAgentID: "eebe4d02"))

        #expect(image.width == 12)
        #expect(image.height == 16)
    }
}
