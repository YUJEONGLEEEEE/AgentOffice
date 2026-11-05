import Foundation
import Testing
@testable import AgentOfficeKit

struct AgentEventTests {

    @Test func parsesHookLogLines() {
        let log = """
        {"ts":"2026-11-05T07:10:04Z","event":"SessionStart","session":"s1","project":"AgentOffice","source":"startup"}
        {"ts":"2026-11-05T07:10:12Z","event":"PreToolUse","session":"s1","project":"AgentOffice","tool":"Bash"}
        """

        let events = AgentEvent.parseLog(log)

        #expect(events.count == 2)
        #expect(events[0].kind == .sessionStart)
        #expect(events[1].kind == .preToolUse)
        #expect(events[1].tool == "Bash")
        #expect(events[1].project == "AgentOffice")
        #expect(events[1].timestamp == Date(timeIntervalSince1970: 1_793_862_612))
    }

    @Test func skipsBrokenLines() {
        let log = """
        {"ts":"2026-11-05T07:10:04Z","event":"SessionStart","session":"s1","project":"AgentOffice"}
        this is not json
        {"ts":"2026-11-05T07:10:12Z","event":"Stop","session":"s1","project":"AgentOffice"}
        """

        #expect(AgentEvent.parseLog(log).map(\.kind) == [.sessionStart, .stop])
    }

    @Test func decodesUnknownEventKind() {
        let log = #"{"ts":"2026-11-05T07:10:04Z","event":"SomethingNew","session":"s1","project":"AgentOffice"}"#

        #expect(AgentEvent.parseLog(log).first?.kind == .unknown)
    }

    @Test func readsSubagentFields() {
        let log = #"{"ts":"2026-11-05T07:10:04Z","event":"PreToolUse","session":"s1","project":"AgentOffice","tool":"Read","agentId":"a1","agentType":"Explore"}"#

        let event = AgentEvent.parseLog(log).first

        #expect(event?.agentID == "a1")
        #expect(event?.agentType == "Explore")
        #expect(event?.isFromSubagent == true)
    }
}
