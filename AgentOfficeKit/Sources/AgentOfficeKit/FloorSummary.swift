import Foundation

/// One floor of the office (one project folder), as shown on the elevator buttons.
public struct FloorSummary: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    /// Agents on this floor who have not left.
    public let presentCount: Int
    public let lastActivity: Date

    public init(name: String, presentCount: Int, lastActivity: Date) {
        self.name = name
        self.presentCount = presentCount
        self.lastActivity = lastActivity
    }

    /// One summary per floor, sorted by name so the buttons stay in place like a real elevator.
    public static func floors(from snapshots: [AgentSnapshot]) -> [FloorSummary] {
        Dictionary(grouping: snapshots, by: \.floor)
            .map { name, agents in
                FloorSummary(
                    name: name,
                    presentCount: agents.filter { $0.status != .left }.count,
                    lastActivity: agents.map(\.lastActivity).max() ?? .distantPast
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
