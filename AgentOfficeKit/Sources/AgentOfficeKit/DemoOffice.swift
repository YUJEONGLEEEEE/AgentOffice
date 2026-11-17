import Foundation

/// A made-up office for trying the app without Claude Code, and for App Review.
///
/// Two projects work through a two-minute script that repeats: reading files, calling team members,
/// editing code, running a command that needs permission, and resting. The script is written as the same
/// events the hook records, so the demo goes through the same rules as real work.
///
/// Demo data stays on the device. It is never written to the events folder or sent to iCloud,
/// and answering its permission question runs nothing.
public enum DemoOffice {

    /// The length of one run of the script. It then starts over.
    public static let loopDuration: TimeInterval = 120

    /// Everything the office shows at one moment of the demo.
    public struct State: Sendable {
        /// Working sessions first, like the real office.
        public let sessions: [AgentSession]
        /// Latest first.
        public let activity: [ActivityEntry]
        /// The demo's permission question, while it is open.
        public let approval: ApprovalRequest?

        public func snapshots(at now: Date) -> [AgentSnapshot] {
            sessions.flatMap { $0.snapshots(at: now) }
        }
    }

    static let lunchSession = "a7c2d0e1-demo-lunch"
    static let portfolioSession = "b91f3c44-demo-portfolio"
    static let lunchProject = "LunchPicker"
    static let portfolioProject = "Portfolio"

    /// When the permission question is open, in seconds into the loop.
    static let approvalWindow: Range<TimeInterval> = 43..<58

    /// One line of the script.
    struct Step {
        let at: TimeInterval
        let session: String
        let kind: AgentEvent.Kind
        var tool: String?
        /// Set for a team member's step.
        var member: (id: String, type: String)?
    }

    static let script: [Step] = {
        let lunch = lunchSession
        let site = portfolioSession
        let ios = (id: "a7c2-ios", type: "ios-developer")
        let qa = (id: "a7c2-qa", type: "qa-reviewer")
        let researcher = (id: "b91f-research", type: "market-researcher")
        let designer = (id: "b91f-design", type: "ui-designer")
        return [
            // LunchPicker: the leader plans, the iOS developer builds, a command waits for permission, QA checks.
            Step(at: 0, session: lunch, kind: .sessionStart),
            Step(at: 3, session: lunch, kind: .userPromptSubmit),
            Step(at: 6, session: lunch, kind: .preToolUse, tool: "Read"),
            Step(at: 12, session: lunch, kind: .preToolUse, tool: "TodoWrite"),
            Step(at: 15, session: lunch, kind: .subagentStart, member: ios),
            Step(at: 19, session: lunch, kind: .preToolUse, tool: "Edit", member: ios),
            Step(at: 32, session: lunch, kind: .preToolUse, tool: "Bash", member: ios),
            Step(at: 40, session: lunch, kind: .subagentStop, member: ios),
            Step(at: 42, session: lunch, kind: .preToolUse, tool: "Bash"),
            Step(at: approvalWindow.lowerBound, session: lunch, kind: .permissionRequest, tool: "Bash"),
            Step(at: approvalWindow.upperBound, session: lunch, kind: .postToolUse, tool: "Bash"),
            Step(at: 61, session: lunch, kind: .subagentStart, member: qa),
            Step(at: 65, session: lunch, kind: .preToolUse, tool: "Grep", member: qa),
            Step(at: 80, session: lunch, kind: .subagentStop, member: qa),
            Step(at: 84, session: lunch, kind: .stop),

            // Portfolio: research on the web, design work, then editing the site.
            Step(at: 5, session: site, kind: .sessionStart),
            Step(at: 9, session: site, kind: .userPromptSubmit),
            Step(at: 12, session: site, kind: .preToolUse, tool: "WebSearch"),
            Step(at: 16, session: site, kind: .subagentStart, member: researcher),
            Step(at: 20, session: site, kind: .preToolUse, tool: "WebFetch", member: researcher),
            Step(at: 38, session: site, kind: .subagentStop, member: researcher),
            Step(at: 41, session: site, kind: .preToolUse, tool: "Glob"),
            Step(at: 50, session: site, kind: .subagentStart, member: designer),
            Step(at: 54, session: site, kind: .preToolUse, tool: "Read", member: designer),
            Step(at: 72, session: site, kind: .subagentStop, member: designer),
            Step(at: 75, session: site, kind: .preToolUse, tool: "Write"),
            Step(at: 92, session: site, kind: .preToolUse, tool: "Bash"),
            Step(at: 100, session: site, kind: .stop),
        ]
    }()

    /// The demo office at `now`. The previous run of the script is included,
    /// so starting over looks like the next day of work instead of everyone vanishing.
    public static func state(at now: Date) -> State {
        let seconds = now.timeIntervalSinceReferenceDate
        let loop = (seconds / loopDuration).rounded(.down)
        let loopStart = Date(timeIntervalSinceReferenceDate: loop * loopDuration)
        let elapsed = now.timeIntervalSince(loopStart)

        var sessions: [AgentSession] = []
        var activity: [ActivityEntry] = []
        for id in [lunchSession, portfolioSession] {
            let previous = script.filter { $0.session == id }
                .map { event(for: $0, at: loopStart.addingTimeInterval($0.at - loopDuration)) }
            let current = script.filter { $0.session == id && $0.at <= elapsed }
                .map { event(for: $0, at: loopStart.addingTimeInterval($0.at)) }
            let events = (previous + current).sorted { $0.timestamp < $1.timestamp }
            if let session = AgentSession(events: events) {
                sessions.append(session)
            }
            activity += AgentSession.activity(from: events)
        }
        sessions.sort { lhs, rhs in
            let lhsWorking = lhs.status(at: now) != .resting
            let rhsWorking = rhs.status(at: now) != .resting
            return lhsWorking != rhsWorking ? lhsWorking : lhs.lastActivity > rhs.lastActivity
        }

        let approval = approvalWindow.contains(elapsed)
            ? ApprovalRequest(id: "demo-\(Int(loop))", sessionID: lunchSession, project: lunchProject,
                              tool: "Bash", summary: "swift test",
                              createdAt: loopStart.addingTimeInterval(approvalWindow.lowerBound))
            : nil
        return State(sessions: sessions, activity: activity.sorted { $0.time > $1.time }, approval: approval)
    }

    /// Whether a permission question belongs to the demo, so answering it can be ignored safely.
    public static func isDemo(_ request: ApprovalRequest) -> Bool {
        request.sessionID == lunchSession || request.sessionID == portfolioSession
    }

    private static func event(for step: Step, at time: Date) -> AgentEvent {
        AgentEvent(timestamp: time, kind: step.kind, sessionID: step.session,
                   project: step.session == lunchSession ? lunchProject : portfolioProject,
                   tool: step.tool, agentID: step.member?.id, agentType: step.member?.type)
    }
}
