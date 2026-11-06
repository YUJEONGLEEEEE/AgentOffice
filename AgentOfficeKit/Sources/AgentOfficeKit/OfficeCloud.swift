import CloudKit
import Foundation

/// Syncs the office summary through the user's private iCloud database.
///
/// The Mac app publishes `AgentSnapshot`s and the iPhone app reads them.
/// Only the summary fields of a snapshot are stored, never prompts, code, commands or paths,
/// and the private database is visible only to the user's own Apple Account.
public actor OfficeCloud {

    public static let containerIdentifier = "iCloud.com.aspyn.AgentOffice"

    /// What the iPhone receives: everyone in the office and when the Mac last checked in.
    public struct Office: Sendable {
        public let agents: [AgentSnapshot]
        /// When the Mac last published, even if nothing changed. `nil` if it never did.
        public let lastUpdated: Date?
    }

    public enum CloudError: Error, Equatable {
        /// The device is not signed in to iCloud, or iCloud Drive is restricted.
        case accountUnavailable
    }

    static let zoneID = CKRecordZone.ID(zoneName: "Office", ownerName: CKCurrentUserDefaultName)
    static let agentRecordType = "Agent"
    static let statusRecordType = "OfficeStatus"
    static let statusRecordID = CKRecord.ID(recordName: "status", zoneID: zoneID)

    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }
    private var hasZone = false
    private var publishedIDs: Set<String> = []

    public init() {
        container = CKContainer(identifier: Self.containerIdentifier)
    }

    // MARK: - Mac

    /// Saves the current agents, removes agents that are gone, and records the time.
    public func publish(_ agents: [AgentSnapshot], at now: Date) async throws {
        try await ensureAccount()
        try await ensureZone()

        let records = agents.map { Self.record(for: $0) }
        let status = CKRecord(recordType: Self.statusRecordType, recordID: Self.statusRecordID)
        status["lastUpdated"] = now

        let currentIDs = Set(agents.map(\.id))
        let removed = publishedIDs.subtracting(currentIDs).map { CKRecord.ID(recordName: $0, zoneID: Self.zoneID) }

        _ = try await database.modifyRecords(saving: records + [status], deleting: removed, savePolicy: .allKeys)
        publishedIDs = currentIDs
    }

    /// Tells the iPhone the Mac is still running, without touching the agents.
    public func sendHeartbeat(at now: Date) async throws {
        try await ensureAccount()
        try await ensureZone()
        let status = CKRecord(recordType: Self.statusRecordType, recordID: Self.statusRecordID)
        status["lastUpdated"] = now
        _ = try await database.modifyRecords(saving: [status], deleting: [], savePolicy: .allKeys)
    }

    /// Learns which agents are already in iCloud, so agents that left while the Mac app was closed get removed.
    public func loadPublishedIDs() async throws {
        let office = try await fetch()
        publishedIDs = Set(office.agents.map(\.id))
    }

    // MARK: - iPhone

    /// Reads everything in the office zone. The data is small, so it reads the whole zone each time.
    public func fetch() async throws -> Office {
        try await ensureAccount()
        var agents: [AgentSnapshot] = []
        var lastUpdated: Date?
        var token: CKServerChangeToken?
        var moreComing = true

        do {
            while moreComing {
                let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
                for (_, result) in changes.modificationResultsByID {
                    guard let record = try? result.get().record else { continue }
                    if record.recordType == Self.statusRecordType {
                        lastUpdated = record["lastUpdated"] as? Date
                    } else if let agent = Self.snapshot(from: record) {
                        agents.append(agent)
                    }
                }
                token = changes.changeToken
                moreComing = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            // The Mac has not published anything yet.
            return Office(agents: [], lastUpdated: nil)
        }
        return Office(agents: agents.sorted { $0.id < $1.id }, lastUpdated: lastUpdated)
    }

    // MARK: - Setup

    private func ensureAccount() async throws {
        guard try await container.accountStatus() == .available else {
            throw CloudError.accountUnavailable
        }
    }

    private func ensureZone() async throws {
        guard !hasZone else { return }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
        hasZone = true
    }

    // MARK: - Records

    /// The only fields that leave the Mac.
    static let agentFields = ["name", "floor", "room", "status", "lastActivity", "role"]

    static func record(for agent: AgentSnapshot) -> CKRecord {
        let record = CKRecord(recordType: agentRecordType, recordID: CKRecord.ID(recordName: agent.id, zoneID: zoneID))
        record["name"] = agent.name
        record["floor"] = agent.floor
        record["room"] = agent.room.rawValue
        record["status"] = agent.status.rawValue
        record["lastActivity"] = agent.lastActivity
        record["role"] = agent.role
        return record
    }

    static func snapshot(from record: CKRecord) -> AgentSnapshot? {
        guard
            record.recordType == agentRecordType,
            let name = record["name"] as? String,
            let floor = record["floor"] as? String,
            let room = (record["room"] as? String).flatMap(Room.init(rawValue:)),
            let status = (record["status"] as? String).flatMap(AgentStatus.init(rawValue:)),
            let lastActivity = record["lastActivity"] as? Date
        else { return nil }
        return AgentSnapshot(id: record.recordID.recordName, name: name, floor: floor, room: room,
                             status: status, lastActivity: lastActivity, role: record["role"] as? String)
    }
}

extension AgentSnapshot {

    /// The status to show on a device that received this snapshot earlier.
    /// The one-hour inactivity rule still applies even if the Mac stopped sending updates.
    public func status(at now: Date) -> AgentStatus {
        now.timeIntervalSince(lastActivity) >= AgentSession.inactivityLimit ? .left : status
    }
}
