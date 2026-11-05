import Foundation
import Testing
@testable import AgentOfficeKit

struct AgentSessionTests {

    private let start = Date(timeIntervalSince1970: 1_793_862_600)

    private func event(
        _ kind: AgentEvent.Kind,
        after seconds: TimeInterval = 0,
        tool: String? = nil,
        agentID: String? = nil,
        agentType: String = "market-researcher",
        notification: String? = nil
    ) -> AgentEvent {
        AgentEvent(
            timestamp: start.addingTimeInterval(seconds),
            kind: kind,
            sessionID: "s1",
            project: "AgentOffice",
            tool: tool,
            agentID: agentID,
            agentType: agentID == nil ? nil : agentType,
            notification: notification
        )
    }

    @Test func returnsNilWithoutEvents() {
        #expect(AgentSession(events: []) == nil)
    }

    @Test func followsFullWorkday() throws {
        var session = try #require(AgentSession(events: [event(.sessionStart)]))
        #expect(session.status(at: start) == .arrived)
        #expect(session.room == .desk)

        session.apply(event(.userPromptSubmit, after: 6))
        #expect(session.status(at: start) == .received)

        session.apply(event(.preToolUse, after: 8, tool: "Bash"))
        #expect(session.status(at: start) == .working)
        #expect(session.room == .serverRoom)

        session.apply(event(.stop, after: 18))
        #expect(session.status(at: start) == .resting)
        #expect(session.room == .breakRoom)

        session.apply(event(.sessionEnd, after: 45))
        #expect(session.status(at: start) == .left)
    }

    @Test func restsInBreakRoomThenReturnsToDeskForNextPrompt() throws {
        var session = try #require(AgentSession(events: [
            event(.preToolUse, tool: "Edit"),
            event(.stop, after: 5),
        ]))
        #expect(session.room == .breakRoom)

        session.apply(event(.userPromptSubmit, after: 30))
        #expect(session.recordedStatus == .received)
        #expect(session.room == .desk)
    }

    @Test func permissionPromptMeansWaitingInSameRoom() throws {
        let session = try #require(AgentSession(events: [
            event(.preToolUse, tool: "Edit"),
            event(.notification, after: 1, notification: "permission_prompt"),
        ]))

        #expect(session.recordedStatus == .waiting)
        #expect(session.room == .devRoom)
    }

    @Test func otherNotificationsDoNotChangeStatus() throws {
        let session = try #require(AgentSession(events: [
            event(.preToolUse, tool: "Read"),
            event(.notification, after: 1, notification: "idle_prompt"),
        ]))

        #expect(session.recordedStatus == .working)
    }

    @Test func leavesAfterOneHourWithoutActivity() throws {
        let session = try #require(AgentSession(events: [event(.preToolUse, tool: "Bash")]))

        #expect(session.status(at: start.addingTimeInterval(59 * 60)) == .working)
        #expect(session.status(at: start.addingTimeInterval(60 * 60)) == .left)
    }

    @Test func sessionWithoutStartEventStillWorks() throws {
        // Sessions that began before the hook was installed have no SessionStart.
        let session = try #require(AgentSession(events: [
            event(.userPromptSubmit),
            event(.preToolUse, after: 4, tool: "Bash"),
        ]))

        #expect(session.recordedStatus == .working)
        #expect(session.project == "AgentOffice")
    }

    @Test func subagentToolUseDoesNotMoveMainAgent() throws {
        let session = try #require(AgentSession(events: [
            event(.preToolUse, tool: "Agent"),
            event(.subagentStart, after: 1, agentID: "a1"),
            event(.preToolUse, after: 2, tool: "Read", agentID: "a1"),
        ]))

        #expect(session.room == .meetingRoom)
        #expect(session.activeSubagentIDs == ["a1"])
        #expect(session.lastActivity == start.addingTimeInterval(2))
    }

    @Test func subagentStopRemovesSubagent() throws {
        let session = try #require(AgentSession(events: [
            event(.subagentStart, agentID: "a1"),
            event(.subagentStart, after: 1, agentID: "a2"),
            event(.subagentStop, after: 2, agentID: "a1"),
        ]))

        #expect(session.activeSubagentIDs == ["a2"])
    }

    @Test func teamMemberStartsInMeetingRoomThenMovesByTool() throws {
        var session = try #require(AgentSession(events: [
            event(.preToolUse, tool: "Agent"),
            event(.subagentStart, after: 1, agentID: "a1", agentType: "ios-developer"),
        ]))
        let member = try #require(session.teamMembers["a1"])
        #expect(member.room == .meetingRoom)
        #expect(member.status == .arrived)
        #expect(member.role.title == "iOS 개발자")
        #expect(member.role.department == .development)

        session.apply(event(.preToolUse, after: 2, tool: "Edit", agentID: "a1", agentType: "ios-developer"))
        #expect(session.teamMembers["a1"]?.room == .devRoom)
        #expect(session.teamMembers["a1"]?.status == .working)
    }

    @Test func ignoresInternalHelpersWithoutAgentType() throws {
        let session = try #require(AgentSession(events: [
            event(.sessionStart),
            event(.subagentStart, after: 1, agentID: "x1", agentType: ""),
            event(.preToolUse, after: 2, tool: "Read", agentID: "x1", agentType: ""),
        ]))

        #expect(session.teamMembers.isEmpty)
    }

    @Test func addsTeamMemberWhenStartWasMissed() throws {
        let session = try #require(AgentSession(events: [
            event(.sessionStart),
            event(.preToolUse, after: 1, tool: "WebSearch", agentID: "a1"),
        ]))

        #expect(session.teamMembers["a1"]?.room == .researchRoom)
    }

    @Test func snapshotsIncludeTeamMembersWhileLeaderIsIn() throws {
        let session = try #require(AgentSession(events: [
            event(.sessionStart),
            event(.subagentStart, after: 1, agentID: "a1", agentType: "qa-reviewer"),
        ]))

        let snapshots = session.snapshots(at: start.addingTimeInterval(2))
        #expect(snapshots.map(\.name) == ["s1", "QA 검토자 · s1"])
        #expect(snapshots.last?.role == "qa-reviewer")
        #expect(snapshots.last?.id == "s1.a1")

        let later = session.snapshots(at: start.addingTimeInterval(AgentSession.inactivityLimit + 10))
        #expect(later.count == 1)
    }

    @Test func ignoresEventsFromOtherSessions() throws {
        var session = try #require(AgentSession(events: [event(.stop)]))
        let other = AgentEvent(timestamp: start, kind: .preToolUse, sessionID: "s2", project: "Other", tool: "Bash")

        session.apply(other)

        #expect(session.recordedStatus == .resting)
        #expect(session.project == "AgentOffice")
    }
}
