import Foundation
import Testing
@testable import AgentOfficeKit

struct AgentSnapshotTests {

    private let start = Date(timeIntervalSince1970: 1_793_862_600)

    private func session(_ events: [(AgentEvent.Kind, String?)]) throws -> AgentSession {
        let list = events.enumerated().map { index, item in
            AgentEvent(timestamp: start.addingTimeInterval(TimeInterval(index)), kind: item.0,
                       sessionID: "eebe4d02-c840", project: "AgentOffice", tool: item.1)
        }
        return try #require(AgentSession(events: list))
    }

    @Test func summarizesSession() throws {
        let snapshot = try session([(.sessionStart, nil), (.preToolUse, "Bash")]).snapshot(at: start)

        #expect(snapshot.id == "eebe4d02-c840")
        #expect(snapshot.name == "eebe")
        #expect(snapshot.floor == "AgentOffice")
        #expect(snapshot.room == .serverRoom)
        #expect(snapshot.status == .working)
    }

    @Test func appliesInactivityRule() throws {
        let snapshot = try session([(.preToolUse, "Bash")]).snapshot(at: start.addingTimeInterval(60 * 60 + 1))

        #expect(snapshot.status == .left)
    }

    @Test func encodesOnlySummaryFields() throws {
        let snapshot = try session([(.preToolUse, "Read")]).snapshot(at: start)
        let data = try JSONEncoder().encode(snapshot)
        let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys

        #expect(Set(keys) == ["id", "name", "floor", "room", "status", "lastActivity"])
    }
}

struct AgentAppearanceTests {

    @Test func sameIDAlwaysLooksTheSame() {
        #expect(AgentAppearance(id: "eebe4d02") == AgentAppearance(id: "eebe4d02"))
    }

    @Test func usesPaletteColors() {
        let appearance = AgentAppearance(id: "e77b1e86")

        #expect(AgentAppearance.hairColors.contains(appearance.hair))
        #expect(AgentAppearance.shirtColors.contains(appearance.shirt))
    }
}
