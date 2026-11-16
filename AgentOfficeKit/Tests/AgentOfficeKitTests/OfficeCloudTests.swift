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

    // MARK: - Approvals

    private func approval(agentID: String? = nil) -> ApprovalRequest {
        ApprovalRequest(id: "a1b2-c3", sessionID: "eebe4d02", agentID: agentID, project: "AgentOffice",
                        tool: "Bash", summary: "touch hello.txt", createdAt: now)
    }

    @Test func approvalRecordRoundTrip() throws {
        let record = OfficeCloud.record(for: approval(agentID: "a1"))

        #expect(try #require(OfficeCloud.approval(from: record)) == approval(agentID: "a1"))
        #expect(record["agentName"] as? String == "eebe")
    }

    /// The command must never be stored as a plain field, only end-to-end encrypted.
    @Test func approvalCommandIsOnlyEncrypted() {
        let record = OfficeCloud.record(for: approval())

        // allKeys() also lists encrypted fields; the plain value must still be missing.
        #expect(Set(record.allKeys()).isSubset(of: Set(OfficeCloud.approvalFields + ["summary"])))
        #expect(record["summary"] == nil)
        #expect(record.encryptedValues["summary"] as? String == "touch hello.txt")
    }

    @Test func approvalRecordIsNotAnAgent() {
        let record = OfficeCloud.record(for: approval())

        #expect(OfficeCloud.snapshot(from: record) == nil)
        #expect(OfficeCloud.approval(from: OfficeCloud.record(for: agent())) == nil)
    }
}
