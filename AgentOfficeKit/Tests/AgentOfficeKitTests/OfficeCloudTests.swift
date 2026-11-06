import CloudKit
import Foundation
import Testing
@testable import AgentOfficeKit

struct OfficeCloudTests {

    private let now = Date(timeIntervalSince1970: 1_793_862_600)

    private func agent(role: String? = "market-researcher") -> AgentSnapshot {
        AgentSnapshot(id: "eebe4d02.a1", name: "eebe", floor: "AgentOffice", room: .researchRoom,
                      status: .working, lastActivity: now, role: role)
    }

    @Test func recordRoundTrip() throws {
        let record = OfficeCloud.record(for: agent())
        let snapshot = try #require(OfficeCloud.snapshot(from: record))

        #expect(snapshot == agent())
        #expect(record.recordID.zoneID.zoneName == "Office")
    }

    @Test func leaderRecordHasNoRole() throws {
        let record = OfficeCloud.record(for: agent(role: nil))

        #expect(record["role"] == nil)
        #expect(OfficeCloud.snapshot(from: record)?.role == nil)
    }

    /// Only the summary leaves the Mac: nothing else may be added to the record by mistake.
    @Test func recordHoldsOnlySummaryFields() {
        let record = OfficeCloud.record(for: agent())

        #expect(Set(record.allKeys()).isSubset(of: Set(OfficeCloud.agentFields)))
    }

    @Test func ignoresBrokenRecords() {
        let record = OfficeCloud.record(for: agent())
        record["room"] = "rooftop"

        #expect(OfficeCloud.snapshot(from: record) == nil)
    }

    @Test func receivedSnapshotStillLeavesAfterAnHour() {
        #expect(agent().status(at: now.addingTimeInterval(60)) == .working)
        #expect(agent().status(at: now.addingTimeInterval(AgentSession.inactivityLimit)) == .left)
    }
}
