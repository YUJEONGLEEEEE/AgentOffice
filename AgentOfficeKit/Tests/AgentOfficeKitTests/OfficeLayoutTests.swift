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

    @Test func convertsToSceneCoordinates() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

        #expect(layout.sceneRect(rect) == CGRect(x: 10, y: 580, width: 30, height: 40))
        #expect(layout.scenePoint(CGPoint(x: 10, y: 20)) == CGPoint(x: 10, y: 620))
    }
}
