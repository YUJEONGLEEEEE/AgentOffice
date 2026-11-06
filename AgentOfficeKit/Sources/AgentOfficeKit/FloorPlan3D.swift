import CoreGraphics
import Foundation

/// The plan of one floor in the 3D view: rooms, furniture, seats and routes.
///
/// Distances are in floor units (about a meter). `x` runs left to right and `z` from the back wall
/// toward the viewer, so a `CGRect` here means x/z with a top-left origin, like the 2D layouts.
/// The plan has no RealityKit types, so it can be tested without drawing anything.
public struct FloorPlan3D: Sendable {

    public static let standard = FloorPlan3D()

    public let size = CGSize(width: 24, height: 13.6)
    /// The corridor between the back row and the front row of rooms. Rooms open onto it.
    public let aisle = CGRect(x: 0, y: 6, width: 24, height: 1.6)
    /// Where new arrivals come in and people who leave go out.
    public let entrance = CGPoint(x: 0.5, y: 6.8)

    public func frame(of room: Room) -> CGRect {
        switch room {
        case .meetingRoom: CGRect(x: 0, y: 0, width: 8, height: 6)
        case .archive: CGRect(x: 8, y: 0, width: 8, height: 6)
        case .researchRoom: CGRect(x: 16, y: 0, width: 8, height: 6)
        case .devRoom: CGRect(x: 0, y: 7.6, width: 7, height: 6)
        case .desk: CGRect(x: 7, y: 7.6, width: 7, height: 6)
        case .serverRoom: CGRect(x: 14, y: 7.6, width: 4.5, height: 6)
        case .breakRoom: CGRect(x: 18.5, y: 7.6, width: 5.5, height: 6)
        }
    }

    // MARK: - Walls and furniture

    /// Walls between neighboring rooms in the same row. Rooms in different rows meet through the aisle.
    public var partitions: [CGRect] {
        [8, 16].map { CGRect(x: $0 - 0.1, y: 0, width: 0.2, height: 6) }
            + [7, 14, 18.5].map { CGRect(x: $0 - 0.1, y: 7.6, width: 0.2, height: 6) }
    }

    public struct Furniture: Sendable, Equatable {
        public enum Kind: Sendable, Equatable {
            case table, desk, monitor, whiteboard, shelf, rack, terminal, coffeeMachine, fridge, sofa, lowTable, plant
        }
        public let kind: Kind
        /// The footprint on the floor.
        public let footprint: CGRect
        /// How tall it is, and how high it starts (a monitor sits on a desk).
        public let height: Double
        public let elevation: Double

        init(_ kind: Kind, _ x: Double, _ z: Double, _ width: Double, _ depth: Double, height: Double, elevation: Double = 0) {
            self.kind = kind
            footprint = CGRect(x: x, y: z, width: width, height: depth)
            self.height = height
            self.elevation = elevation
        }

        /// Whether people walk around it. Things on a desk or on a wall do not block the floor.
        public var blocksFloor: Bool { elevation == 0 && kind != .whiteboard }
    }

    public let furniture: [Furniture] = [
        // Meeting room: whiteboard on the back wall, a table in the middle
        Furniture(.whiteboard, 1.5, 0.1, 5, 0.15, height: 2, elevation: 0.7),
        Furniture(.table, 2, 2.6, 4, 1.4, height: 0.8),
        Furniture(.plant, 7.1, 0.4, 0.6, 0.6, height: 1.2),
        // Archive: shelves along the back wall, a reading table
        Furniture(.shelf, 8.6, 0.25, 1.8, 0.8, height: 2.6),
        Furniture(.shelf, 10.8, 0.25, 1.8, 0.8, height: 2.6),
        Furniture(.shelf, 13, 0.25, 1.8, 0.8, height: 2.6),
        Furniture(.table, 10, 3, 3, 1.2, height: 0.75),
        // Research room: a long desk with two screens
        Furniture(.desk, 17, 1.6, 6, 1.2, height: 0.8),
        Furniture(.monitor, 17.9, 1.7, 1.3, 0.15, height: 0.9, elevation: 0.8),
        Furniture(.monitor, 20.9, 1.7, 1.3, 0.15, height: 0.9, elevation: 0.8),
        Furniture(.plant, 23.1, 0.4, 0.6, 0.6, height: 1.4),
        // Dev room: two desks with two screens each
        Furniture(.desk, 1, 8.8, 2.4, 1.2, height: 0.8),
        Furniture(.desk, 4, 8.8, 2.4, 1.2, height: 0.8),
        Furniture(.monitor, 1.3, 8.9, 0.85, 0.12, height: 0.8, elevation: 0.8),
        Furniture(.monitor, 2.25, 8.9, 0.85, 0.12, height: 0.8, elevation: 0.8),
        Furniture(.monitor, 4.3, 8.9, 0.85, 0.12, height: 0.8, elevation: 0.8),
        Furniture(.monitor, 5.25, 8.9, 0.85, 0.12, height: 0.8, elevation: 0.8),
        // Workspace: two rows of desks
        Furniture(.desk, 7.8, 8.6, 2.4, 1.1, height: 0.8),
        Furniture(.desk, 10.9, 8.6, 2.4, 1.1, height: 0.8),
        Furniture(.desk, 7.8, 11.3, 2.4, 1.0, height: 0.8),
        Furniture(.desk, 10.9, 11.3, 2.4, 1.0, height: 0.8),
        Furniture(.monitor, 8.5, 8.7, 1, 0.12, height: 0.75, elevation: 0.8),
        Furniture(.monitor, 11.6, 8.7, 1, 0.12, height: 0.75, elevation: 0.8),
        Furniture(.monitor, 8.5, 11.4, 1, 0.12, height: 0.75, elevation: 0.8),
        Furniture(.monitor, 11.6, 11.4, 1, 0.12, height: 0.75, elevation: 0.8),
        // Server room: two racks and a terminal
        Furniture(.rack, 14.4, 7.9, 1.1, 1.2, height: 2.8),
        Furniture(.rack, 15.9, 7.9, 1.1, 1.2, height: 2.8),
        Furniture(.terminal, 16.3, 11.5, 1.8, 0.9, height: 0.8),
        Furniture(.monitor, 16.7, 11.55, 1, 0.12, height: 0.7, elevation: 0.8),
        // Break room: coffee machine, fridge, sofa and a low table
        Furniture(.coffeeMachine, 19, 7.9, 1, 0.8, height: 1.8),
        Furniture(.fridge, 20.3, 7.9, 1, 0.8, height: 2.2),
        Furniture(.lowTable, 20.4, 10.3, 1.4, 0.9, height: 0.5),
        Furniture(.sofa, 19.4, 12.1, 3.6, 1.1, height: 0.7),
        Furniture(.plant, 23.1, 8.1, 0.6, 0.6, height: 1.3),
    ]

    // MARK: - Where people stand

    /// A place to stand or sit, the way the person faces (radians around the vertical axis,
    /// 0 = toward the viewer, π = toward the back wall), and what they do there.
    public struct Spot: Sendable, Equatable {
        public let point: CGPoint
        public let facing: Double
        public let act: FloorAct?

        init(_ x: Double, _ z: Double, facing: Double = .pi, act: FloorAct? = nil) {
            point = CGPoint(x: x, y: z)
            self.facing = facing
            self.act = act
        }
    }

    /// Each team member's own chair, facing their desk.
    public func seat(forAgentType agentType: String) -> (room: Room, spot: Spot)? {
        switch agentType {
        case "contest-analyst": (.desk, Spot(9, 10.4))
        case "service-planner": (.desk, Spot(12.1, 10.4))
        case "pitch-writer": (.desk, Spot(9, 12.9))
        case "market-researcher": (.researchRoom, Spot(18.55, 3.35))
        case "data-analyst": (.researchRoom, Spot(21.55, 3.35))
        case "ui-designer": (.archive, Spot(11.5, 4.75))
        case "ios-developer": (.devRoom, Spot(2.2, 10.6))
        case "web-developer": (.devRoom, Spot(5.2, 10.6))
        case "qa-reviewer": (.serverRoom, Spot(17.2, 13.0))
        default: nil
        }
    }

    /// Places for anyone else in a room, in the order they fill up.
    public func visitorSpots(in room: Room) -> [Spot] {
        switch room {
        case .meetingRoom:
            [Spot(4, 1.25, act: .writing), Spot(2.6, 4.7), Spot(4, 4.7), Spot(5.4, 4.7), Spot(1.2, 3.3, facing: .pi / 2), Spot(6.8, 3.3, facing: -.pi / 2)]
        case .archive:
            [Spot(9.5, 1.75, act: .reading), Spot(11.7, 1.75, act: .reading), Spot(13.9, 1.75, act: .reading), Spot(15.2, 4.4, facing: -.pi / 2), Spot(9, 4.6, facing: .pi / 2)]
        case .researchRoom:
            [Spot(20, 3.35), Spot(23, 3.35), Spot(17.5, 4.9), Spot(22.6, 5.1)]
        case .devRoom:
            [Spot(3.6, 12.6), Spot(1.4, 12.6), Spot(5.8, 12.6), Spot(0.6, 10.6, facing: .pi / 2)]
        case .desk:
            [Spot(12.1, 12.9), Spot(13.4, 10.4, facing: -.pi / 2), Spot(10.5, 13.1, facing: 0)]
        case .serverRoom:
            [Spot(15, 9.95, facing: .pi), Spot(16.4, 9.95, facing: .pi), Spot(15.2, 12.6, facing: .pi / 2)]
        case .breakRoom:
            [Spot(19.5, 9.4, facing: .pi), Spot(22.6, 10.2, facing: .pi / 2 + .pi), Spot(22.6, 11.5, facing: -.pi / 2), Spot(19.1, 10.8, facing: .pi / 2)]
        }
    }

    // MARK: - Walking

    private static let cell: Double = 0.2
    private static let clearance: Double = 0.3

    private var columns: Int { Int((size.width / Self.cell).rounded(.up)) }
    private var rows: Int { Int((size.height / Self.cell).rounded(.up)) }

    /// Whether a person can stand here: inside a room or the aisle, clear of walls and furniture.
    public func isWalkable(_ point: CGPoint) -> Bool {
        let margin = Self.clearance
        let areas = Room.allCases.map { frame(of: $0) } + [aisle]
        let outer = CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin)
        guard outer.contains(point), areas.contains(where: { $0.contains(point) }) else { return false }
        if partitions.contains(where: { $0.insetBy(dx: -margin, dy: -margin).contains(point) }) { return false }
        return !furniture.contains { $0.blocksFloor && $0.footprint.insetBy(dx: -margin, dy: -margin).contains(point) }
    }

    private func index(of point: CGPoint) -> Int {
        let column = min(columns - 1, max(0, Int(point.x / Self.cell)))
        let row = min(rows - 1, max(0, Int(point.y / Self.cell)))
        return row * columns + column
    }

    private func center(of index: Int) -> CGPoint {
        CGPoint(x: (Double(index % columns) + 0.5) * Self.cell, y: (Double(index / columns) + 0.5) * Self.cell)
    }

    /// The way from one point to another around walls and furniture, as corner points ending at `end`.
    /// Returns a straight line when no route exists, so nobody gets stuck.
    public func route(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let walkable = (0..<(columns * rows)).map { isWalkable(center(of: $0)) }
        let startIndex = nearestWalkable(index(of: start), walkable)
        let goalIndex = nearestWalkable(index(of: end), walkable)
        guard startIndex != goalIndex else { return [end] }

        var open = MinHeap()
        var cameFrom: [Int: Int] = [:]
        var cost: [Int: Int] = [startIndex: 0]
        open.push(startIndex, priority: 0)
        let goal = center(of: goalIndex)

        while let current = open.pop() {
            if current == goalIndex { break }
            let row = current / columns, column = current % columns
            for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let r = row + dr, c = column + dc
                guard r >= 0, r < rows, c >= 0, c < columns else { continue }
                let next = r * columns + c
                guard walkable[next] else { continue }
                // Turning costs a little, so routes take few corners.
                let turn = cameFrom[current].map { previous in (current - previous) != (next - current) ? 2 : 0 } ?? 0
                let newCost = (cost[current] ?? 0) + 10 + turn
                if newCost < cost[next, default: .max] {
                    cost[next] = newCost
                    cameFrom[next] = current
                    let p = center(of: next)
                    let estimate = Int((abs(p.x - goal.x) + abs(p.y - goal.y)) / Self.cell * 10)
                    open.push(next, priority: newCost + estimate)
                }
            }
        }

        guard cameFrom[goalIndex] != nil else { return [end] }
        var path = [goalIndex]
        while let previous = cameFrom[path[path.count - 1]] { path.append(previous) }
        let points = path.reversed().map(center(of:))
        // Keep only the corners.
        var corners: [CGPoint] = []
        for (i, point) in points.enumerated() where i > 0 && i < points.count - 1 {
            let a = points[i - 1], b = points[i + 1]
            if !((a.x == point.x && point.x == b.x) || (a.y == point.y && point.y == b.y)) { corners.append(point) }
        }
        return corners + [end]
    }

    private func nearestWalkable(_ start: Int, _ walkable: [Bool]) -> Int {
        guard !walkable[start] else { return start }
        let origin = center(of: start)
        return walkable.indices.filter { walkable[$0] }.min {
            let a = center(of: $0), b = center(of: $1)
            return hypot(a.x - origin.x, a.y - origin.y) < hypot(b.x - origin.x, b.y - origin.y)
        } ?? start
    }

    // MARK: - Placing everyone

    public struct Placement: Sendable, Equatable {
        public let point: CGPoint
        public let facing: Double
        public let act: FloorAct
        /// Sitting at a desk rather than standing.
        public let isSeated: Bool
    }

    /// Where everyone on the floor is and what they are doing.
    ///
    /// Team members in the room of their own desk use their chair; everyone else fills the room's spots in order.
    public func placements(for agents: [AgentSnapshot]) -> [String: Placement] {
        var result: [String: Placement] = [:]
        var used: [Room: Int] = [:]
        for agent in agents.filter({ $0.status != .left }).sorted(by: { ($0.role != nil ? 1 : 0, $0.id) < ($1.role != nil ? 1 : 0, $1.id) }) {
            if let role = agent.role, let seat = seat(forAgentType: role), seat.room == agent.room {
                let act = FloorAct(status: agent.status, room: agent.room, seated: true)
                result[agent.id] = Placement(point: seat.spot.point, facing: seat.spot.facing, act: act, isSeated: true)
                continue
            }
            let spots = visitorSpots(in: agent.room)
            let index = used[agent.room, default: 0]
            used[agent.room] = index + 1
            let base = spots[index % spots.count]
            // Extra people beyond the spots stand a little to the side of an earlier one.
            let extra = Double(index / spots.count) * 0.7
            let point = CGPoint(x: base.point.x + extra, y: base.point.y)
            let act = base.act.map { agent.status == .working ? $0 : FloorAct(status: agent.status, room: agent.room, seated: false) }
                ?? FloorAct(status: agent.status, room: agent.room, seated: false)
            result[agent.id] = Placement(point: isWalkable(point) ? point : base.point, facing: base.facing, act: act, isSeated: false)
        }
        return result
    }
}

/// What a person in the 3D office is doing, which decides how they move.
public enum FloorAct: Sendable, Equatable {
    case typing
    case writing
    case reading
    case coffee
    case raisingHand
    case waitingAtDesk
    case standing

    init(status: AgentStatus, room: Room, seated: Bool) {
        switch status {
        case .waiting: self = .raisingHand
        case .idle: self = seated ? .waitingAtDesk : .standing
        case .resting: self = room == .breakRoom ? .coffee : .standing
        case .arrived, .received, .left: self = .standing
        case .working:
            switch room {
            case .meetingRoom: self = .writing
            case .archive: self = .reading
            case .breakRoom: self = .coffee
            case .researchRoom, .devRoom, .desk, .serverRoom: self = .typing
            }
        }
    }
}
