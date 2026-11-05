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
        case .meetingRoom: CGPoint(x: 298, y: 150)
        case .archive: CGPoint(x: 578, y: 160)
        case .researchRoom: CGPoint(x: 1050, y: 210)
        case .devRoom: CGPoint(x: 232, y: 455)
        case .desk: CGPoint(x: 554, y: 460)
        case .serverRoom: CGPoint(x: 870, y: 580)
        case .breakRoom: CGPoint(x: 1064, y: 470)
        }
    }

    /// Where several agents in the same room stand, so they do not overlap.
    public func spot(for room: Room, index: Int) -> CGPoint {
        let base = spot(for: room)
        let interior = interior(for: room).insetBy(dx: 20, dy: 20)
        let column = index % 5
        let row = index / 5
        let offsets: [CGFloat] = [0, -56, 56, -112, 112]
        let point = CGPoint(x: base.x + offsets[column], y: base.y + CGFloat(row) * 36)
        return CGPoint(
            x: min(max(point.x, interior.minX), interior.maxX),
            y: min(max(point.y, interior.minY), interior.maxY)
        )
    }

    /// Where agents step out of the elevator when they arrive, and where they leave.
    public let elevatorSpot = CGPoint(x: 44, y: 300)

    /// The vertical center of the hallway, where agents walk between rooms.
    public var hallwayWalkY: CGFloat { hallway.midY }

    /// The horizontal center of the door between a room and the hallway.
    public func doorX(for room: Room) -> CGFloat {
        switch room {
        case .meetingRoom: 180
        case .archive: 500
        case .researchRoom: 910
        case .devRoom: 230
        case .desk: 620
        case .serverRoom: 865
        case .breakRoom: 1050
        }
    }

    /// A point just inside a room, in front of its door.
    public func insideDoor(for room: Room) -> CGPoint {
        let interior = interior(for: room)
        let isAboveHallway = interior.maxY <= hallway.minY
        return CGPoint(x: doorX(for: room), y: isAboveHallway ? interior.maxY - 16 : interior.minY + 16)
    }

    /// The route an agent walks, in top-left coordinates. `nil` means the elevator.
    ///
    /// Agents leave through their room's door, walk along the hallway and enter through
    /// the target room's door, so they never walk through walls.
    public func path(from start: Room?, startIndex: Int = 0, to end: Room?, endIndex: Int = 0) -> [CGPoint] {
        let target = end.map { spot(for: $0, index: endIndex) } ?? elevatorSpot
        if start == end {
            return [target]
        }

        var points: [CGPoint] = []
        if let start {
            let door = insideDoor(for: start)
            points.append(door)
            points.append(CGPoint(x: door.x, y: hallwayWalkY))
        } else {
            points.append(CGPoint(x: elevatorSpot.x, y: hallwayWalkY))
        }

        if let end {
            let door = insideDoor(for: end)
            points.append(CGPoint(x: door.x, y: hallwayWalkY))
            points.append(door)
        } else {
            points.append(CGPoint(x: elevatorSpot.x, y: hallwayWalkY))
        }
        points.append(target)
        return points
    }

    /// Converts a top-left based rect to SpriteKit coordinates.
    public func sceneRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Converts a top-left based point to SpriteKit coordinates.
    public func scenePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }
}
