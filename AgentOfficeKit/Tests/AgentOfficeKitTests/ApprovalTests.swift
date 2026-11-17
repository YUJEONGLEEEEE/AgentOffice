import Foundation
import Testing
@testable import AgentOfficeKit

struct ApprovalFolderTests {

    private let now = Date(timeIntervalSince1970: 1_794_000_000)

    private func makeFolder() throws -> ApprovalFolder {
        let url = FileManager.default.temporaryDirectory.appending(path: "approvals-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return ApprovalFolder(url: url)
    }

    private func writeRequest(_ json: String, id: String, in folder: ApprovalFolder) throws {
        try Data(json.utf8).write(to: folder.url.appending(path: "\(id).request.json"))
    }

    @Test func readsRequestsWrittenByTheHook() throws {
        let folder = try makeFolder()
        try writeRequest("""
        {"id":"b-2","session":"970b1234","project":"AgentOffice","tool":"Bash","summary":"rm -rf build","ts":"2026-11-17T08:00:30Z"}
        """, id: "b-2", in: folder)
        try writeRequest("""
        {"id":"a-1","session":"e36a5678","agentId":"x1","project":"Blog","tool":"Edit","summary":"~/Blog/index.md","ts":"2026-11-17T08:00:00Z"}
        """, id: "a-1", in: folder)

        let requests = folder.requests(now: ISO8601DateFormatter().date(from: "2026-11-17T08:01:00Z")!)

        #expect(requests.map(\.id) == ["a-1", "b-2"])
        #expect(requests[0].agentID == "x1")
        #expect(requests[1].summary == "rm -rf build")
        #expect(requests[1].agentName == "970b")
    }

    @Test func ignoresOldBrokenAndUnsafeRequests() throws {
        let folder = try makeFolder()
        try writeRequest("""
        {"id":"old","session":"s","project":"P","tool":"Bash","summary":"","ts":"2026-11-17T07:00:00Z"}
        """, id: "old", in: folder)
        try writeRequest("not json", id: "broken", in: folder)
        try writeRequest("""
        {"id":"../escape","session":"s","project":"P","tool":"Bash","summary":"","ts":"2026-11-17T08:00:00Z"}
        """, id: "unsafe", in: folder)

        #expect(folder.requests(now: ISO8601DateFormatter().date(from: "2026-11-17T08:01:00Z")!).isEmpty)
    }

    @Test func writesAnAnswerTheHookCanRead() throws {
        let folder = try makeFolder()
        let request = ApprovalRequest(id: "c-3", sessionID: "s", project: "P", tool: "Bash", summary: "ls", createdAt: now)

        try folder.answer(request, with: .deny)

        let data = try Data(contentsOf: folder.url.appending(path: "c-3.answer.json"))
        let answer = try JSONDecoder().decode([String: String].self, from: data)
        #expect(answer == ["id": "c-3", "decision": "deny"])
    }

    @Test func refusesToAnswerAnUnsafeID() throws {
        let folder = try makeFolder()
        let request = ApprovalRequest(id: "../x", sessionID: "s", project: "P", tool: "Bash", summary: "", createdAt: now)

        #expect(throws: (any Error).self) { try folder.answer(request, with: .allow) }
    }

    @Test func removesAnswersWhoseQuestionEnded() throws {
        let folder = try makeFolder()
        let open = ApprovalRequest(id: "open-1", sessionID: "s", project: "P", tool: "Bash", summary: "", createdAt: .now)
        let ended = ApprovalRequest(id: "ended-1", sessionID: "s", project: "P", tool: "Bash", summary: "", createdAt: .now)
        try Data("{}".utf8).write(to: folder.url.appending(path: "open-1.request.json"))
        try folder.answer(open, with: .allow)
        try folder.answer(ended, with: .deny)

        folder.removeUnclaimedAnswers()

        #expect(FileManager.default.fileExists(atPath: folder.url.appending(path: "open-1.answer.json").path))
        #expect(!FileManager.default.fileExists(atPath: folder.url.appending(path: "ended-1.answer.json").path))
    }

    @Test func marksTheAppAliveAndClosed() throws {
        let folder = try makeFolder()
        let alive = folder.url.appending(path: ApprovalFolder.aliveFileName)

        try folder.markAlive(now: now)
        #expect(FileManager.default.fileExists(atPath: alive.path))

        folder.markClosed()
        #expect(!FileManager.default.fileExists(atPath: alive.path))
    }
}

struct PermissionEventTests {

    private let start = Date(timeIntervalSince1970: 1_794_000_000)

    private func event(_ kind: AgentEvent.Kind, _ seconds: Double, tool: String? = nil, agentID: String? = nil) -> AgentEvent {
        AgentEvent(timestamp: start.addingTimeInterval(seconds), kind: kind, sessionID: "s1", project: "P",
                   tool: tool, agentID: agentID, agentType: agentID == nil ? nil : "researcher")
    }

    @Test func askingForPermissionRaisesAHandUntilTheToolRuns() throws {
        var session = try #require(AgentSession(events: [
            event(.sessionStart, 0),
            event(.preToolUse, 1, tool: "Bash"),
            event(.permissionRequest, 2, tool: "Bash"),
        ]))
        #expect(session.recordedStatus == .waiting)

        session.apply(event(.postToolUse, 9, tool: "Bash"))
        #expect(session.recordedStatus == .working)
        #expect(session.room == .serverRoom)
    }

    @Test func aTeamMemberAsksWithoutStoppingTheLeader() throws {
        var session = try #require(AgentSession(events: [
            event(.sessionStart, 0),
            event(.subagentStart, 1, agentID: "m1"),
            event(.preToolUse, 2, tool: "WebFetch", agentID: "m1"),
            event(.permissionRequest, 3, tool: "WebFetch", agentID: "m1"),
        ]))
        #expect(session.teamMembers["m1"]?.status == .waiting)
        #expect(session.recordedStatus != .waiting)

        session.apply(event(.postToolUse, 5, tool: "WebFetch", agentID: "m1"))
        #expect(session.teamMembers["m1"]?.status == .working)
    }
}
