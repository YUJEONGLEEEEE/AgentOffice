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

    @Test func spreadSpotsAreOnFreeFloorInsideTheRoom() {
        for room in Room.allCases {
            for index in 0..<8 {
                let spot = layout.spot(for: room, index: index)
                #expect(layout.interior(for: room).contains(spot), "\(room) #\(index)")
                #expect(layout.isWalkable(spot), "\(room) #\(index) is on furniture or too close to a wall")
            }
        }
    }

    @Test func spreadSpotsKeepAgentsApart() {
        for room in Room.allCases {
            let chairs = OfficeTeam.roster.compactMap { layout.seat(forAgentType: $0.agentType) }.filter { $0.room == room }.map(\.point)
            let spots = (0..<10).map { layout.spot(for: room, index: $0) }
            for (i, a) in spots.enumerated() {
                for b in spots[(i + 1)...] + chairs {
                    #expect(hypot(a.x - b.x, a.y - b.y) >= OfficeLayout.personSpacing, "\(room) #\(i) is too close to \(b)")
                }
            }
        }
    }

    @Test func firstSpotsStayWhereTheyWere() {
        // Up to three agents in a room stand where they always have.
        #expect(layout.spot(for: .devRoom, index: 0) == layout.spot(for: .devRoom))
        #expect(layout.spot(for: .devRoom, index: 1) == CGPoint(x: 176, y: 602))
        #expect(layout.spot(for: .devRoom, index: 2) == CGPoint(x: 288, y: 602))
    }

    @Test func elevatorSpotIsWalkable() {
        #expect(layout.isWalkable(layout.elevatorSpot))
    }

    @Test func furnitureIsNotWalkable() {
        for piece in layout.furniture {
            #expect(!layout.isWalkable(CGPoint(x: piece.midX, y: piece.midY)), "\(piece)")
        }
    }

    /// Everything the scene draws as furniture must be listed in the layout, or agents would walk over it.
    @Test @MainActor func layoutListsAllDrawnFurniture() {
        let scene = OfficeScene(layout: layout)
        scene.buildIfNeeded()

        #expect(!scene.furnitureFrames.isEmpty)
        for frame in scene.furnitureFrames {
            #expect(layout.furniture.contains { $0.contains(frame) }, "\(frame) is drawn but not in the layout")
        }
    }

    /// Every step of every route stays on free floor: no walls, no furniture.
    @Test(arguments: [Room?.none] + Room.allCases.map(Optional.some))
    func routesAvoidWallsAndFurniture(from start: Room?) {
        for end in [Room?.none] + Room.allCases.map(Optional.some) {
            for (startIndex, endIndex) in [(0, 0), (1, 2), (4, 3)] {
                let first = start.map { layout.spot(for: $0, index: startIndex) } ?? layout.elevatorSpot
                let points = [first] + layout.path(from: start, startIndex: startIndex, to: end, endIndex: endIndex)
                let label = "\(String(describing: start)) → \(String(describing: end))"
                for (from, to) in zip(points, points.dropFirst()) {
                    let steps = max(1, Int(hypot(to.x - from.x, to.y - from.y)))
                    let crossesBlockedFloor = (0...steps).contains { step in
                        let t = CGFloat(step) / CGFloat(steps)
                        return !layout.isWalkable(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
                    }
                    #expect(!crossesBlockedFloor, "\(label): \(from) → \(to)")
                }
                let target = end.map { layout.spot(for: $0, index: endIndex) } ?? layout.elevatorSpot
                #expect(points.last == target, "\(label) does not reach its spot")
            }
        }
    }

    @Test func convertsToSceneCoordinates() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

        #expect(layout.sceneRect(rect) == CGRect(x: 10, y: 580, width: 30, height: 40))
        #expect(layout.scenePoint(CGPoint(x: 10, y: 20)) == CGPoint(x: 10, y: 620))
    }
}
