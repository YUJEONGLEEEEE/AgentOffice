import CoreGraphics

/// The floor plan of one office floor.
///
/// Frames use a top-left origin (like the design mockup) so the numbers are easy to read.
/// Use `sceneRect(_:)` and `scenePoint(_:)` to convert them to SpriteKit's bottom-left origin.
public struct OfficeLayout: Sendable {

    public static let standard = OfficeLayout()

    public let size = CGSize(width: 1160, height: 640)
    public let wallThickness: CGFloat = 6

    /// The corridor between the top and bottom rows of rooms.
    public let hallway = CGRect(x: 0, y: 250, width: 1160, height: 66)

    /// Gaps in the walls between the rooms and the hallway.
    public let doors: [CGRect] = [
        CGRect(x: 150, y: 250, width: 60, height: 6),
        CGRect(x: 470, y: 250, width: 60, height: 6),
        CGRect(x: 880, y: 250, width: 60, height: 6),
        CGRect(x: 200, y: 310, width: 60, height: 6),
        CGRect(x: 590, y: 310, width: 60, height: 6),
        CGRect(x: 840, y: 310, width: 50, height: 6),
        CGRect(x: 1020, y: 310, width: 60, height: 6),
    ]

    /// The floor space taken by furniture. Agents walk around these.
    ///
    /// Each rect covers one piece or one group, such as a desk with its monitor and chair.
    public let furniture: [CGRect] = {
        var rects: [CGRect] = [
            // Hallway: card reader, plants and water cooler
            CGRect(x: 88, y: 266, width: 12, height: 18),
            CGRect(x: 302, y: 258, width: 20, height: 30),
            CGRect(x: 1112, y: 258, width: 20, height: 30),
            CGRect(x: 690, y: 256, width: 20, height: 34),
            // Meeting room: whiteboard, table with chairs, plant
            CGRect(x: 130, y: 8, width: 150, height: 40),
            CGRect(x: 70, y: 94, width: 190, height: 100),
            CGRect(x: 298, y: 190, width: 20, height: 42),
            // Archive: bookshelves, filing cabinet, reading table with chairs
            CGRect(x: 476, y: 8, width: 258, height: 50),
            CGRect(x: 692, y: 96, width: 34, height: 92),
            CGRect(x: 410, y: 150, width: 150, height: 74),
            // Research room: world map, globe
            CGRect(x: 890, y: 8, width: 180, height: 48),
            CGRect(x: 1088, y: 82, width: 44, height: 64),
            // Server room: air conditioner, racks
            CGRect(x: 888, y: 318, width: 58, height: 18),
            CGRect(x: 794, y: 380, width: 94, height: 130),
            CGRect(x: 896, y: 574, width: 50, height: 26),
            // Break room: fridge and coffee machine, vending machine, round table, sofa, plant
            CGRect(x: 1072, y: 318, width: 68, height: 44),
            CGRect(x: 1100, y: 380, width: 36, height: 64),
            CGRect(x: 998, y: 458, width: 56, height: 56),
            CGRect(x: 980, y: 562, width: 120, height: 40),
            CGRect(x: 1118, y: 556, width: 20, height: 42),
        ]
        // Research desks with monitors and chairs
        for x in [770, 886, 1002] {
            rects.append(CGRect(x: x, y: 140, width: 96, height: 72))
        }
        // Dev room desks with two monitors and a chair
        for y in [380, 510] {
            for x in [30, 170, 310] {
                rects.append(CGRect(x: x, y: y - 12, width: 120, height: 78))
            }
        }
        // Work area desks with a monitor and a chair
        for y in [384, 510] {
            for x in [490, 632] {
                rects.append(CGRect(x: x, y: y - 12, width: 112, height: 82))
            }
        }
        return rects
    }()

    /// Where agents step out of the elevator when they arrive, and where they leave.
    public let elevatorSpot = CGPoint(x: 44, y: 300)

    /// Side length of one cell of the walking grid.
    static let cellSize: CGFloat = 4
    private let columns: Int
    private let rows: Int
    private var walkableCells: [Bool] = []
    /// Spots for several agents in each room, worked out once so they never overlap.
    private var spreadSpots: [Room: [CGPoint]] = [:]

    /// How far apart two agents stand, at least, so neither hides the other.
    static let personSpacing: CGFloat = 34
    /// How many agents each room has separate spots for.
    static let spotsPerRoom = 15

    public init() {
        columns = Int(size.width / Self.cellSize)
        rows = Int(size.height / Self.cellSize)
        walkableCells = (0..<(columns * rows)).map { isWalkable(center(of: $0)) }
        for room in Room.allCases {
            spreadSpots[room] = makeSpreadSpots(for: room)
        }
    }

    // MARK: - Rooms

    /// The outer frame of a room, walls included. Neighboring rooms share a wall.
    public func frame(for room: Room) -> CGRect {
        switch room {
        case .meetingRoom: CGRect(x: 0, y: 0, width: 346, height: 256)
        case .archive: CGRect(x: 340, y: 0, width: 406, height: 256)
        case .researchRoom: CGRect(x: 740, y: 0, width: 420, height: 256)
        case .devRoom: CGRect(x: 0, y: 310, width: 466, height: 330)
        case .desk: CGRect(x: 460, y: 310, width: 326, height: 330)
        case .serverRoom: CGRect(x: 780, y: 310, width: 186, height: 330)
        case .breakRoom: CGRect(x: 960, y: 310, width: 200, height: 330)
        }
    }

    /// The floor area inside a room's walls.
    public func interior(for room: Room) -> CGRect {
        frame(for: room).insetBy(dx: wallThickness, dy: wallThickness)
    }

    /// Where an agent stands when it is in the room (the point under its feet).
    public func spot(for room: Room) -> CGPoint {
        switch room {
        case .meetingRoom: CGPoint(x: 165, y: 216)
        case .archive: CGPoint(x: 600, y: 112)
        case .researchRoom: CGPoint(x: 1050, y: 238)
        case .devRoom: CGPoint(x: 232, y: 602)
        case .desk: CGPoint(x: 660, y: 606)
        case .serverRoom: CGPoint(x: 840, y: 566)
        case .breakRoom: CGPoint(x: 1076, y: 526)
        }
    }

    /// Where several agents in the same room stand, so they do not overlap.
    public func spot(for room: Room, index: Int) -> CGPoint {
        guard let spots = spreadSpots[room], !spots.isEmpty else { return spot(for: room) }
        return spots[index % spots.count]
    }

    /// Spots in rows around the room's main spot. A spot on furniture moves to the nearest free floor,
    /// and one that would end up too close to an earlier spot or a team member's chair is skipped.
    private func makeSpreadSpots(for room: Room) -> [CGPoint] {
        let base = spot(for: room)
        let area = interior(for: room)
        let chairs = OfficeTeam.roster.compactMap { seat(forAgentType: $0.agentType) }.filter { $0.room == room }.map(\.point)
        let columnOffsets: [CGFloat] = [0, -56, 56, -112, 112, -168, 168, -224, 224]
        let rowOffsets: [CGFloat] = [0, 36, -36, 72, -72, 108, -108]

        var spots: [CGPoint] = []
        func isClear(_ point: CGPoint) -> Bool {
            (spots + chairs).allSatisfy { hypot($0.x - point.x, $0.y - point.y) >= Self.personSpacing }
        }
        for dy in rowOffsets {
            for dx in columnOffsets where spots.count < Self.spotsPerRoom {
                let wanted = CGPoint(x: base.x + dx, y: base.y + dy)
                let point = area.contains(wanted) && isWalkable(wanted) ? wanted : nearestWalkablePoint(to: wanted, in: area)
                if let point, isClear(point) {
                    spots.append(point)
                }
            }
        }
        return spots.isEmpty ? [base] : spots
    }

    // MARK: - Seats

    /// Each team member's own desk, where they wait when they have nothing to do.
    /// The point is just in front of their chair.
    public func seat(forAgentType agentType: String) -> (room: Room, point: CGPoint)? {
        switch agentType {
        case "contest-analyst": (.desk, CGPoint(x: 546, y: 466))
        case "service-planner": (.desk, CGPoint(x: 688, y: 466))
        case "pitch-writer": (.desk, CGPoint(x: 546, y: 592))
        case "market-researcher": (.researchRoom, CGPoint(x: 818, y: 224))
        case "data-analyst": (.researchRoom, CGPoint(x: 934, y: 224))
        case "ui-designer": (.archive, CGPoint(x: 450, y: 238))
        case "ios-developer": (.devRoom, CGPoint(x: 90, y: 458))
        case "web-developer": (.devRoom, CGPoint(x: 230, y: 458))
        case "qa-reviewer": (.serverRoom, CGPoint(x: 924, y: 610))
        default: nil
        }
    }

    // MARK: - Walking

    /// Whether an agent can stand here: on the floor of a room, the hallway or a doorway,
    /// away from the walls and not on furniture.
    public func isWalkable(_ point: CGPoint) -> Bool {
        let blocked = furniture.contains { piece in
            CGRect(x: piece.minX - 12, y: piece.minY - 4, width: piece.width + 24, height: piece.height + 10).contains(point)
        }
        guard !blocked else { return false }
        return walkingAreas.contains { $0.contains(point) }
    }

    /// Floor where feet can go. The top edge leaves room for the agent's body in front of the wall.
    private var walkingAreas: [CGRect] {
        let areas = Room.allCases.map(interior(for:)) + [hallway.insetBy(dx: 0, dy: wallThickness)]
        let floors = areas.map { area in
            CGRect(x: area.minX + 14, y: area.minY + 16, width: area.width - 28, height: area.height - 18)
        }
        let doorways = doors.map { door in
            CGRect(x: door.minX + 14, y: door.minY - 20, width: door.width - 28, height: door.height + 40)
        }
        return floors + doorways
    }

    /// The route an agent walks, in top-left coordinates. `nil` means the elevator.
    ///
    /// The route goes around furniture and through doors, turning at right angles like a pixel game.
    /// The last point is always the destination spot.
    public func path(from start: Room?, startIndex: Int = 0, to end: Room?, endIndex: Int = 0) -> [CGPoint] {
        let origin = start.map { spot(for: $0, index: startIndex) } ?? elevatorSpot
        let target = end.map { spot(for: $0, index: endIndex) } ?? elevatorSpot
        return path(from: origin, to: target)
    }

    /// The route between two points on the floor, in top-left coordinates.
    public func path(from origin: CGPoint, to target: CGPoint) -> [CGPoint] {
        guard let from = cell(at: origin), let to = cell(at: target), walkableCells[from], walkableCells[to] else {
            return [target]
        }

        let cells = route(from: from, to: to)
        var points = [origin]
        for (index, cell) in cells.enumerated() {
            let point = center(of: cell)
            let isLast = index == cells.count - 1
            if !isLast {
                // Skip points in the middle of a straight line.
                let next = center(of: cells[index + 1])
                if let previous = points.last, Self.isStraight(previous, point, next) {
                    continue
                }
            }
            points.append(point)
        }
        points.append(target)
        return Array(points.dropFirst())
    }

    // MARK: - Grid

    private static func isStraight(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        let vertical = a.x == b.x && b.x == c.x
        let horizontal = a.y == b.y && b.y == c.y
        return vertical || horizontal
    }

    private func center(of cell: Int) -> CGPoint {
        CGPoint(x: (CGFloat(cell % columns) + 0.5) * Self.cellSize, y: (CGFloat(cell / columns) + 0.5) * Self.cellSize)
    }

    private func cell(at point: CGPoint) -> Int? {
        let column = Int(point.x / Self.cellSize)
        let row = Int(point.y / Self.cellSize)
        guard (0..<columns).contains(column), (0..<rows).contains(row) else { return nil }
        return row * columns + column
    }

    private func nearestWalkablePoint(to point: CGPoint, in area: CGRect) -> CGPoint? {
        walkableCells.indices
            .filter { walkableCells[$0] && area.contains(center(of: $0)) }
            .map(center(of:))
            .min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) }
    }

    /// A* search over the walking grid with four directions. Turns cost a little extra,
    /// so routes prefer long straight lines.
    private func route(from start: Int, to goal: Int) -> [Int] {
        let goalColumn = goal % columns, goalRow = goal / columns
        func estimate(_ cell: Int) -> Int {
            abs(cell % columns - goalColumn) + abs(cell / columns - goalRow)
        }

        var cost = [Int](repeating: .max, count: walkableCells.count)
        var cameFrom = [Int](repeating: -1, count: walkableCells.count)
        var open = MinHeap()
        cost[start] = 0
        open.push(start, priority: estimate(start))

        while let current = open.pop() {
            if current == goal { break }
            let column = current % columns
            let step = cameFrom[current] < 0 ? 0 : current - cameFrom[current]
            for next in [current - 1, current + 1, current - columns, current + columns] {
                guard next >= 0, next < walkableCells.count, walkableCells[next] else { continue }
                if (next == current - 1 && column == 0) || (next == current + 1 && column == columns - 1) { continue }
                let turn = step != 0 && next - current != step ? 3 : 0
                let newCost = cost[current] + 1 + turn
                if newCost < cost[next] {
                    cost[next] = newCost
                    cameFrom[next] = current
                    open.push(next, priority: newCost + estimate(next))
                }
            }
        }

        guard cost[goal] != .max else { return [] }
        var cells = [goal]
        while let last = cells.last, last != start {
            cells.append(cameFrom[last])
        }
        return cells.reversed()
    }

    // MARK: - Scene coordinates

    /// Converts a top-left based rect to SpriteKit coordinates.
    public func sceneRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Converts a top-left based point to SpriteKit coordinates.
    public func scenePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }
}

/// A small binary heap for the route search.
struct MinHeap {
    private var items: [(value: Int, priority: Int)] = []

    mutating func push(_ value: Int, priority: Int) {
        items.append((value, priority))
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard items[child].priority < items[parent].priority else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Int? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let top = items.removeLast()
        var parent = 0
        while true {
            let left = parent * 2 + 1, right = left + 1
            var smallest = parent
            if left < items.count, items[left].priority < items[smallest].priority { smallest = left }
            if right < items.count, items[right].priority < items[smallest].priority { smallest = right }
            guard smallest != parent else { break }
            items.swapAt(parent, smallest)
            parent = smallest
        }
        return top.value
    }
}
