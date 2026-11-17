import Foundation

/// A tool that a session wants to use and that needs the user's permission.
///
/// The approval hook writes one request file while Claude Code waits for an answer,
/// and deletes it as soon as the question is answered, here or in the terminal.
/// Unlike the event log, a request shows what will run (the command or file), because
/// the user cannot decide safely without it. It never leaves the Mac in plain text.
public struct ApprovalRequest: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    /// The subagent asking, or nil for the session itself.
    public let agentID: String?
    public let project: String
    public let tool: String
    /// The command, file or address the tool will use. Empty when the tool has nothing to show.
    public let summary: String
    public let createdAt: Date

    public init(id: String, sessionID: String, agentID: String? = nil, project: String,
                tool: String, summary: String, createdAt: Date) {
        self.id = id
        self.sessionID = sessionID
        self.agentID = agentID
        self.project = project
        self.tool = tool
        self.summary = summary
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session"
        case agentID = "agentId"
        case project
        case tool
        case summary
        case createdAt = "ts"
    }

    /// "970b" for the session, like the employee's name.
    public var agentName: String { String(sessionID.prefix(4)) }
}

/// The user's answer to an approval request.
public enum ApprovalDecision: String, Codable, Sendable {
    case allow
    case deny
}

/// The folder where the approval hook and the app talk to each other.
///
/// - `<id>.request.json`: written by the hook, removed by the hook when it ends.
/// - `<id>.answer.json`: written by the app, read and removed by the hook.
/// - `.app-alive`: touched by the app every few seconds. The hook only waits for an answer
///   while it is fresh, so a closed app never delays Claude Code.
public struct ApprovalFolder: Sendable {

    public static let aliveFileName = ".app-alive"
    /// Requests older than this are left over from a hook that was stopped and are ignored.
    public static let requestLifetime: TimeInterval = 10 * 60

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Open requests, oldest first.
    public func requests(now: Date = .now) -> [ApprovalRequest] {
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files
            .filter { $0.lastPathComponent.hasSuffix(".request.json") }
            .compactMap { file in
                guard let data = try? Data(contentsOf: file) else { return nil }
                return try? decoder.decode(ApprovalRequest.self, from: data)
            }
            .filter { now.timeIntervalSince($0.createdAt) < Self.requestLifetime && Self.isSafeID($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Writes the answer in one step, so the hook never reads half a file.
    public func answer(_ request: ApprovalRequest, with decision: ApprovalDecision) throws {
        guard Self.isSafeID(request.id) else { throw CocoaError(.fileWriteInvalidFileName) }
        let body = try JSONEncoder().encode(["id": request.id, "decision": decision.rawValue])
        try body.write(to: url.appending(path: "\(request.id).answer.json"), options: [.atomic])
    }

    /// Removes answers nobody will read: the question ended (answered in the terminal, say)
    /// just as an answer arrived from the app or the iPhone.
    public func removeUnclaimedAnswers() {
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        let names = Set(files.map(\.lastPathComponent))
        for file in files where file.lastPathComponent.hasSuffix(".answer.json") {
            let id = file.lastPathComponent.dropLast(".answer.json".count)
            if !names.contains("\(id).request.json") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Tells the hook the app is open and answering.
    public func markAlive(now: Date = .now) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let file = url.appending(path: Self.aliveFileName)
        try Data(ISO8601DateFormatter().string(from: now).utf8).write(to: file, options: [.atomic])
    }

    /// Tells the hook the app has closed, so it stops waiting at once.
    public func markClosed() {
        try? FileManager.default.removeItem(at: url.appending(path: Self.aliveFileName))
    }

    /// IDs become file names, so only letters, digits and hyphens are allowed.
    static func isSafeID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }
}
