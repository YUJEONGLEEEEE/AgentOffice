import Foundation
import Testing
@testable import AgentOfficeKit

struct DemoOfficeTests {

    /// When the demo was turned on: the script plays from its beginning.
    private let loopStart = Date(timeIntervalSinceReferenceDate: 812_345_678)

    private func state(at seconds: TimeInterval) -> (DemoOffice.State, [AgentSnapshot]) {
        let now = loopStart.addingTimeInterval(seconds)
        let state = DemoOffice.state(at: now, startedAt: loopStart)
        return (state, state.snapshots(at: now))
    }

    @Test func teamMemberWorksInTheirRoom() throws {
        let (_, agents) = state(at: 25)
        let developer = try #require(agents.first { $0.role == "ios-developer" })

        #expect(developer.room == .devRoom)
        #expect(developer.status == .working)
        #expect(developer.floor == "LunchPicker")
    }

    @Test func askingForPermissionShowsAQuestionAndARaisedHand() throws {
        let (state, agents) = state(at: 50)
        let leader = try #require(agents.first { $0.role == nil && $0.floor == "LunchPicker" })
        let question = try #require(state.approval)

        #expect(leader.status == .waiting)
        #expect(question.tool == "Bash")
        #expect(DemoOffice.isDemo(question))
    }

    /// App Review is told the question shows about 45 seconds in, so it must stay up around then.
    @Test func questionShowsAboutFortyFiveSecondsAfterTurningOn() {
        #expect(state(at: 40).0.approval == nil)
        #expect(state(at: 45).0.approval != nil)
        #expect(state(at: 70).0.approval != nil)
        // And again in the next run of the script.
        #expect(state(at: DemoOffice.loopDuration + 45).0.approval != nil)
    }

    @Test func everyoneRestsAtTheEndAndTheQuestionIsGone() {
        let (state, agents) = state(at: 110)

        #expect(state.approval == nil)
        #expect(agents.filter { $0.role == nil }.allSatisfy { $0.status == .resting && $0.room == .breakRoom })
    }

    /// Starting over must not empty the office: the previous run is still there.
    @Test func officeIsNeverEmpty() {
        for second in stride(from: 0.0, to: DemoOffice.loopDuration, by: 1) {
            let (state, agents) = state(at: second)
            #expect(state.sessions.count == 2, "at \(second)s")
            #expect(!agents.isEmpty, "at \(second)s")
            #expect(!state.activity.isEmpty, "at \(second)s")
        }
    }

    @Test func realQuestionsAreNotDemo() {
        let real = ApprovalRequest(id: "x", sessionID: "970b809a", project: "P", tool: "Bash", summary: "", createdAt: .now)

        #expect(!DemoOffice.isDemo(real))
    }
}
