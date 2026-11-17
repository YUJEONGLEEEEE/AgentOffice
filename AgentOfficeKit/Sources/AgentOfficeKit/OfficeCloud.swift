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
        /// Permission questions still waiting for an answer, oldest first.
        public let approvals: [ApprovalRequest]
    }

    public enum CloudError: Error, Equatable {
        /// The device is not signed in to iCloud, or iCloud Drive is restricted.
        case accountUnavailable
    }

    static let zoneID = CKRecordZone.ID(zoneName: "Office", ownerName: CKCurrentUserDefaultName)
    static let agentRecordType = "Agent"
    static let statusRecordType = "OfficeStatus"
    static let statusRecordID = CKRecord.ID(recordName: "status", zoneID: zoneID)
    static let approvalRecordType = "Approval"
    static let approvalSubscriptionID = "approvals"

    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }
    private var hasZone = false
    private var publishedIDs: Set<String> = []
    /// Questions this Mac put in iCloud. `nil` until it has looked at what an earlier run left there.
    private var uploadedApprovalIDs: Set<String>?

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

        try await modify(saving: records + [status], deleting: removed, savePolicy: .allKeys)
        publishedIDs = currentIDs
    }

    /// Tells the iPhone the Mac is still running, without touching the agents.
    public func sendHeartbeat(at now: Date) async throws {
        try await ensureAccount()
        try await ensureZone()
        let status = CKRecord(recordType: Self.statusRecordType, recordID: Self.statusRecordID)
        status["lastUpdated"] = now
        try await modify(saving: [status], deleting: [], savePolicy: .allKeys)
    }

    /// Learns which agents are already in iCloud, so agents that left while the Mac app was closed get removed.
    public func loadPublishedIDs() async throws {
        let office = try await fetch()
        publishedIDs = Set(office.agents.map(\.id))
    }

    /// Puts new permission questions in iCloud, removes answered ones,
    /// and returns the answers given on the iPhone, by question ID.
    public func syncApprovals(_ requests: [ApprovalRequest]) async throws -> [String: ApprovalDecision] {
        // Someone is waiting on these, so CloudKit should not put them off.
        try await database.configuredWith(configuration: Self.waitingConfiguration()) { database in
            try await self.syncApprovals(requests, in: database)
        }
    }

    /// Settings for work a person is waiting on. CloudKit may delay lower-priority work by many seconds.
    static func waitingConfiguration() -> CKOperation.Configuration {
        let configuration = CKOperation.Configuration()
        configuration.qualityOfService = .userInitiated
        return configuration
    }

    private func syncApprovals(_ requests: [ApprovalRequest], in database: CKDatabase) async throws -> [String: ApprovalDecision] {
        try await ensureAccount()
        try await ensureZone()
        if uploadedApprovalIDs == nil {
            // Questions left by a run that quit before they were answered are removed below.
            uploadedApprovalIDs = Set(try await zoneRecords(in: database).filter { $0.recordType == Self.approvalRecordType }
                .map(\.recordID.recordName))
        }
        let uploaded = uploadedApprovalIDs ?? []
        let openIDs = Set(requests.map(\.id))
        // Only new questions are saved, so an answer from the iPhone is never written over.
        let new = requests.filter { !uploaded.contains($0.id) }.map(Self.record(for:))
        let gone = uploaded.subtracting(openIDs).map { CKRecord.ID(recordName: $0, zoneID: Self.zoneID) }
        if !new.isEmpty || !gone.isEmpty {
            // A question that is already there (saved by a sync that failed halfway) counts as uploaded.
            try await modify(saving: new, deleting: gone, savePolicy: .ifServerRecordUnchanged,
                             ignoring: [.serverRecordChanged], in: database)
        }
        uploadedApprovalIDs = openIDs
        guard !openIDs.isEmpty else { return [:] }

        let ids = openIDs.map { CKRecord.ID(recordName: $0, zoneID: Self.zoneID) }
        var answers: [String: ApprovalDecision] = [:]
        for (id, result) in try await database.records(for: ids, desiredKeys: ["decision"]) {
            if let decision = (try? result.get())?["decision"].flatMap({ $0 as? String }).flatMap(ApprovalDecision.init(rawValue:)) {
                answers[id.recordName] = decision
            }
        }
        return answers
    }

    // MARK: - iPhone

    /// Reads everything in the office zone. The data is small, so it reads the whole zone each time.
    public func fetch(now: Date = .now) async throws -> Office {
        try await ensureAccount()
        var agents: [AgentSnapshot] = []
        var approvals: [ApprovalRequest] = []
        var lastUpdated: Date?

        do {
            for record in try await zoneRecords() {
                if record.recordType == Self.statusRecordType {
                    lastUpdated = record["lastUpdated"] as? Date
                } else if let agent = Self.snapshot(from: record) {
                    agents.append(agent)
                } else if let approval = Self.approval(from: record), record["decision"] == nil,
                          now.timeIntervalSince(approval.createdAt) < ApprovalFolder.requestLifetime {
                    approvals.append(approval)
                }
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            // The Mac has not published anything yet.
            return Office(agents: [], lastUpdated: nil, approvals: [])
        }
        return Office(agents: agents.sorted { $0.id < $1.id }, lastUpdated: lastUpdated,
                      approvals: approvals.sorted { $0.createdAt < $1.createdAt })
    }

    /// Sends the user's answer to the Mac. Does nothing if the question was already answered elsewhere.
    public func answer(approvalID: String, with decision: ApprovalDecision) async throws {
        try await database.configuredWith(configuration: Self.waitingConfiguration()) { database in
            try await self.answer(approvalID: approvalID, with: decision, in: database)
        }
    }

    private func answer(approvalID: String, with decision: ApprovalDecision, in database: CKDatabase) async throws {
        try await ensureAccount()
        let id = CKRecord.ID(recordName: approvalID, zoneID: Self.zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
        guard record["decision"] == nil else { return }
        record["decision"] = decision.rawValue
        // Answered in the terminal or on the Mac at the same moment: that answer stands.
        try await modify(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged,
                         ignoring: [.serverRecordChanged, .unknownItem], in: database)
    }

    /// Whether iCloud has this user's sign-up for new questions, for the notification status screen.
    public func hasApprovalSubscription() async throws -> Bool {
        try await ensureAccount()
        do {
            _ = try await database.subscription(for: Self.approvalSubscriptionID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
    }

    /// Asks iCloud to notify this device when a new question arrives.
    /// The notification names the employee and the tool, never the command: notifications are not end-to-end encrypted.
    public func subscribeToApprovals() async throws {
        try await ensureAccount()
        let (saved, _) = try await database.modifySubscriptions(saving: [Self.approvalSubscription()], deleting: [])
        for result in saved.values {
            if case .failure(let error) = result { throw error }
        }
    }

    static func approvalSubscription() -> CKQuerySubscription {
        let subscription = CKQuerySubscription(recordType: approvalRecordType, predicate: NSPredicate(value: true),
                                               subscriptionID: approvalSubscriptionID,
                                               options: [.firesOnRecordCreation])
        subscription.zoneID = zoneID
        let info = CKSubscription.NotificationInfo()
        info.titleLocalizationKey = ApprovalNotification.titleKey
        info.alertLocalizationKey = ApprovalNotification.bodyKey
        info.alertLocalizationArgs = ["agentName", "tool"]
        info.soundName = "default"
        info.category = ApprovalNotification.categoryID
        subscription.notificationInfo = info
        return subscription
    }

    // MARK: - Setup

    private func ensureAccount() async throws {
        guard try await container.accountStatus() == .available else {
            throw CloudError.accountUnavailable
        }
    }

    /// Saves and deletes records, and throws if any one of them failed.
    /// `modifyRecords` reports each record's failure in its results instead of throwing, so they are checked here.
    private func modify(saving: [CKRecord], deleting: [CKRecord.ID],
                        savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
                        ignoring ignored: Set<CKError.Code> = [], in database: CKDatabase? = nil) async throws {
        let database = database ?? self.database
        let (saveResults, deleteResults) = try await database.modifyRecords(saving: saving, deleting: deleting,
                                                                             savePolicy: savePolicy)
        // A record that is already gone is what deleting wanted anyway.
        let deleteIgnored = ignored.union([.unknownItem])
        for result in saveResults.values {
            if case .failure(let error) = result, !Self.error(error, isOneOf: ignored) { throw error }
        }
        for result in deleteResults.values {
            if case .failure(let error) = result, !Self.error(error, isOneOf: deleteIgnored) { throw error }
        }
    }

    private static func error(_ error: Error, isOneOf codes: Set<CKError.Code>) -> Bool {
        (error as? CKError).map { codes.contains($0.code) } ?? false
    }

    /// Every record in the office zone.
    private func zoneRecords(in database: CKDatabase? = nil) async throws -> [CKRecord] {
        let database = database ?? self.database
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var moreComing = true
        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
            records += changes.modificationResultsByID.compactMap { try? $0.value.get().record }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return records
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

// MARK: - Approvals

extension OfficeCloud {

    /// The fields of a question stored as they are. The command or file goes in `encryptedValues`,
    /// which only the user's own devices can read, not even Apple.
    static let approvalFields = ["session", "agentId", "agentName", "project", "tool", "createdAt", "decision"]

    static func record(for request: ApprovalRequest) -> CKRecord {
        let record = CKRecord(recordType: approvalRecordType, recordID: CKRecord.ID(recordName: request.id, zoneID: zoneID))
        record["session"] = request.sessionID
        record["agentId"] = request.agentID
        record["agentName"] = request.agentName
        record["project"] = request.project
        record["tool"] = request.tool
        record["createdAt"] = request.createdAt
        record.encryptedValues["summary"] = request.summary
        return record
    }

    static func approval(from record: CKRecord) -> ApprovalRequest? {
        guard
            record.recordType == approvalRecordType,
            let session = record["session"] as? String,
            let project = record["project"] as? String,
            let tool = record["tool"] as? String,
            let createdAt = record["createdAt"] as? Date
        else { return nil }
        return ApprovalRequest(id: record.recordID.recordName, sessionID: session, agentID: record["agentId"] as? String,
                               project: project, tool: tool,
                               summary: record.encryptedValues["summary"] as? String ?? "", createdAt: createdAt)
    }
}

/// The iPhone notification for a new permission question.
public enum ApprovalNotification {
    /// Text keys in the iPhone app's string catalog. iOS fills them in when the notification arrives.
    public static let titleKey = "Permission needed"
    public static let bodyKey = "%1$@ wants to use %2$@"
    public static let categoryID = "approval"
    public static let allowActionID = "allow"
    public static let denyActionID = "deny"
}

extension AgentSnapshot {

    /// The status to show on a device that received this snapshot earlier.
    /// The one-hour inactivity rule still applies even if the Mac stopped sending updates.
    public func status(at now: Date) -> AgentStatus {
        now.timeIntervalSince(lastActivity) >= AgentSession.inactivityLimit ? .left : status
    }
}
