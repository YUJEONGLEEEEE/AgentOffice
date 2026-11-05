import CoreGraphics
import Testing
@testable import AgentOfficeKit

struct OfficeLayoutTests {

    private let layout = OfficeLayout.standard

    @Test func everyRoomFitsOnTheFloor() {
        let floor = CGRect(origin: .zero, size: layout.size)
        for room in Room.allCases {
            #expect(floor.contains(layout.frame(for: room)), "\(room) is outside the floor")
        }
    }

    @Test func roomInteriorsDoNotOverlap() {
        let rooms = Room.allCases
        for (index, room) in rooms.enumerated() {
            for other in rooms[(index + 1)...] {
                #expect(!layout.interior(for: room).intersects(layout.interior(for: other)), "\(room) overlaps \(other)")
            }
        }
    }

    @Test func roomsDoNotCoverTheHallway() {
        for room in Room.allCases {
            #expect(!layout.interior(for: room).intersects(layout.hallway.insetBy(dx: 0, dy: layout.wallThickness)), "\(room) covers the hallway")
        }
    }

    @Test func everyRoomHasASpotInside() {
        for room in Room.allCases {
            #expect(layout.interior(for: room).contains(layout.spot(for: room)), "\(room) spot is outside the room")
        }
    }

    @Test func spreadSpotsStayInsideTheRoom() {
        for room in Room.allCases {
            for index in 0..<8 {
                #expect(layout.interior(for: room).contains(layout.spot(for: room, index: index)), "\(room) #\(index)")
            }
        }
    }

    @Test func eachDoorIsAGapInTheWall() {
        for room in Room.allCases {
            let x = layout.doorX(for: room)
            #expect(layout.doors.contains { $0.minX < x && x < $0.maxX }, "\(room) has no door at x \(x)")
        }
    }

    /// Every step stays inside one room or the hallway, or passes straight through a door.
    @Test(arguments: [Room?.none] + Room.allCases.map(Optional.some))
    func routesNeverCrossWalls(from start: Room?) {
        let hallway = layout.hallway.insetBy(dx: 0, dy: -1)
        for end in [Room?.none] + Room.allCases.map(Optional.some) {
            let first = start.map { layout.spot(for: $0) } ?? layout.elevatorSpot
            let points = [first] + layout.path(from: start, to: end)
            for (from, to) in zip(points, points.dropFirst()) {
                let areas = Room.allCases.map { layout.interior(for: $0) } + [hallway]
                let sameArea = areas.contains { $0.contains(from) && $0.contains(to) }
                let throughDoor = from.x == to.x && layout.doors.contains { $0.minX < from.x && from.x < $0.maxX }
                #expect(sameArea || throughDoor, "\(String(describing: start)) → \(String(describing: end)): \(from) → \(to)")
            }
            #expect(points.last == (end.map { layout.spot(for: $0) } ?? layout.elevatorSpot))
        }
    }

    @Test func convertsToSceneCoordinates() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

        #expect(layout.sceneRect(rect) == CGRect(x: 10, y: 580, width: 30, height: 40))
        #expect(layout.scenePoint(CGPoint(x: 10, y: 20)) == CGPoint(x: 10, y: 620))
    }
}
