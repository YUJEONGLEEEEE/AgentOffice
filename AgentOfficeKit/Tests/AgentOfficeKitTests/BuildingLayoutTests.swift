import CoreGraphics
import Foundation
import Testing
@testable import AgentOfficeKit

struct BuildingLayoutTests {

    private let floors = ["AgentOffice", "SafeDish", "공모전"]

    @Test func floorsAreNumberedFromTheGroundUp() {
        let layout = BuildingLayout(floors: floors)

        #expect(layout.level(of: "AgentOffice") == 1)
        #expect(layout.level(of: "공모전") == 3)
        #expect(layout.floorsTopDown.first == "공모전")
        #expect(layout.level(of: "Missing") == nil)
    }

    @Test func floorsStackWithoutGapsOrOverlap() throws {
        let layout = BuildingLayout(floors: floors)
        let frames = try layout.floorsTopDown.map { try #require(layout.frame(ofFloor: $0)) }

        for (upper, lower) in zip(frames, frames.dropFirst()) {
            #expect(upper.maxY == lower.minY)
        }
        // The ground floor sits on the lobby.
        #expect(try #require(frames.last).maxY == layout.size.height - BuildingLayout.lobbyHeight)
        #expect(frames.allSatisfy { CGRect(origin: .zero, size: layout.size).contains($0) })
    }

    @Test func roomsFillTheFloorInOrder() throws {
        let layout = BuildingLayout(floors: floors)
        let interior = try #require(layout.interior(ofFloor: "SafeDish"))
        let rooms = try BuildingLayout.roomOrder.map { try #require(layout.frame(of: $0, onFloor: "SafeDish")) }

        #expect(abs(try #require(rooms.first).minX - interior.minX) < 0.001)
        #expect(abs(try #require(rooms.last).maxX - interior.maxX) < 0.001)
        for (left, right) in zip(rooms, rooms.dropFirst()) {
            #expect(abs(left.maxX - right.minX) < 0.001)
        }
        #expect(Set(BuildingLayout.roomOrder) == Set(Room.allCases))
    }

    @Test func manyFloorsMakeTheBuildingTallerInsteadOfThinner() {
        let few = BuildingLayout(floors: ["A"])
        let many = BuildingLayout(floors: (1...12).map { "Project \($0)" })

        #expect(few.floorHeight == BuildingLayout.preferredFloorHeight)
        #expect(many.floorHeight == BuildingLayout.minimumFloorHeight)
        #expect(many.size.height > BuildingLayout.minimumHeight)
        #expect(few.size.height == BuildingLayout.minimumHeight)
    }

    @Test func clickingAFloorFindsIt() throws {
        let layout = BuildingLayout(floors: floors)
        let frame = try #require(layout.frame(ofFloor: "SafeDish"))

        #expect(layout.floor(at: CGPoint(x: frame.midX, y: frame.midY)) == "SafeDish")
        #expect(layout.floor(at: CGPoint(x: frame.midX, y: 2)) == nil)
    }

    @Test func spotsStayInsideTheirRoom() throws {
        let layout = BuildingLayout(floors: floors)
        for room in Room.allCases {
            let frame = try #require(layout.frame(of: room, onFloor: "공모전"))
            for index in 0..<4 {
                let spot = try #require(layout.spot(in: room, onFloor: "공모전", index: index))
                #expect(frame.minX < spot.x && spot.x < frame.maxX, "\(room) \(index)")
                #expect(frame.contains(CGPoint(x: spot.x, y: spot.y - 1)), "\(room) \(index)")
            }
        }
    }

    @Test func scenePointsRoundTrip() {
        let layout = BuildingLayout(floors: floors)
        let point = CGPoint(x: 120, y: 300)

        #expect(layout.layoutPoint(layout.scenePoint(point)) == point)
    }
}

struct OfficeViewStyleTests {

    private func emptyDefaults() throws -> UserDefaults {
        let name = "OfficeViewStyleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsWithTheFloorPlan() throws {
        #expect(OfficeViewStyle.saved(in: try emptyDefaults()) == .flat)
    }

    @Test func remembersTheChoice() throws {
        let defaults = try emptyDefaults()
        OfficeViewStyle.building.save(in: defaults)

        #expect(OfficeViewStyle.saved(in: defaults) == .building)
    }

    @Test func switchLabelsAreShort() {
        #expect(OfficeViewStyle.allCases.map(\.title) == ["2D", "3D"])
    }
}
