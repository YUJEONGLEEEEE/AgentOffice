import CoreGraphics
import Foundation
import Testing
@testable import AgentOfficeKit

struct FloorPlan3DTests {

    private let plan = FloorPlan3D.standard
    private let now = Date(timeIntervalSince1970: 1_793_862_600)

    private func agent(_ id: String, room: Room, status: AgentStatus = .working, role: String? = nil) -> AgentSnapshot {
        AgentSnapshot(id: id, name: "eebe", floor: "AgentOffice", room: room, status: status, lastActivity: now, role: role)
    }

    @Test func roomsCoverTheFloorWithoutOverlapping() {
        let frames = Room.allCases.map(plan.frame(of:))
        for (i, a) in frames.enumerated() {
            #expect(CGRect(origin: .zero, size: plan.size).contains(a))
            #expect(!a.intersects(plan.aisle))
            for b in frames[(i + 1)...] { #expect(!a.intersects(b) || a.intersection(b).width * a.intersection(b).height < 0.0001) }
        }
    }

    @Test func furnitureStaysInsideItsRoom() {
        for piece in plan.furniture {
            #expect(Room.allCases.contains { plan.frame(of: $0).contains(piece.footprint) }, "\(piece)")
        }
    }

    @Test(arguments: OfficeTeam.roster.map(\.agentType))
    func everySeatIsFreeFloorInItsRoom(agentType: String) throws {
        let seat = try #require(plan.seat(forAgentType: agentType))
        #expect(plan.frame(of: seat.room).contains(seat.spot.point))
        #expect(plan.isWalkable(seat.spot.point))
    }

    @Test(arguments: Room.allCases)
    func everyVisitorSpotIsFreeFloorInItsRoom(room: Room) {
        for spot in plan.visitorSpots(in: room) {
            #expect(plan.frame(of: room).contains(spot.point), "\(room) \(spot.point)")
            #expect(plan.isWalkable(spot.point), "\(room) \(spot.point)")
        }
    }

    @Test func spotsAreSpacedApart() {
        var points = OfficeTeam.roster.compactMap { plan.seat(forAgentType: $0.agentType)?.spot.point }
        points += Room.allCases.flatMap { plan.visitorSpots(in: $0).map(\.point) }
        for (i, a) in points.enumerated() {
            for b in points[(i + 1)...] { #expect(hypot(a.x - b.x, a.y - b.y) >= 0.9, "\(a) \(b)") }
        }
    }

    @Test(arguments: Room.allCases)
    func routesFromTheEntranceAvoidFurnitureAndWalls(room: Room) throws {
        let target = try #require(plan.visitorSpots(in: room).first).point
        let path = [plan.entrance] + plan.route(from: plan.entrance, to: target)
        #expect(path.last == target)
        for (a, b) in zip(path, path.dropFirst()) {
            for step in 0...20 {
                let t = Double(step) / 20
                let point = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                #expect(plan.isWalkable(point) || hypot(point.x - target.x, point.y - target.y) < 0.3, "\(room) \(point)")
            }
        }
    }

    @Test func teamMembersWaitAtTheirOwnDesks() throws {
        let researcher = agent(OfficeTeam.residentID(for: "market-researcher"), room: .researchRoom, status: .idle, role: "market-researcher")
        let placement = try #require(plan.placements(for: [researcher])[researcher.id])

        #expect(placement.isSeated)
        #expect(placement.act == .waitingAtDesk)
        #expect(placement.point == plan.seat(forAgentType: "market-researcher")?.spot.point)
    }

    @Test func workInTheirOwnRoomHappensAtTheirDesk() throws {
        let developer = agent("team.ios-developer", room: .devRoom, role: "ios-developer")
        let placement = try #require(plan.placements(for: [developer])[developer.id])

        #expect(placement.isSeated)
        #expect(placement.act == .typing)
    }

    @Test func eachRoomHasItsOwnKindOfWork() throws {
        let agents = [agent("a", room: .meetingRoom), agent("b", room: .archive), agent("c", room: .serverRoom),
                      agent("d", room: .breakRoom, status: .resting), agent("e", room: .devRoom, status: .waiting)]
        let placements = plan.placements(for: agents)

        #expect(placements["a"]?.act == .writing)
        #expect(placements["b"]?.act == .reading)
        #expect(placements["c"]?.act == .typing)
        #expect(placements["d"]?.act == .coffee)
        #expect(placements["e"]?.act == .raisingHand)
    }

    @Test func peopleInTheSameRoomDoNotStandOnTopOfEachOther() {
        for room in Room.allCases {
            let agents = (0..<8).map { agent("s\($0)", room: room) }
            let points = plan.placements(for: agents).values.map(\.point)

            #expect(points.count == agents.count)
            for (i, a) in points.enumerated() {
                #expect(plan.isWalkable(a), "\(room) \(a)")
                for b in points[(i + 1)...] {
                    #expect(hypot(a.x - b.x, a.y - b.y) >= FloorPlan3D.personSpacing - 0.001, "\(room) \(a) \(b)")
                }
            }
        }
    }

    @Test func onlyTheResidentSitsInTheChairWhenSeveralShareARole() {
        // Three researchers searching the web at once: the resident and two extra jobs.
        let resident = agent(OfficeTeam.residentID(for: "market-researcher"), room: .researchRoom, role: "market-researcher")
        let extras = ["a1", "a2"].map { agent($0, room: .researchRoom, role: "market-researcher") }
        let analyst = agent(OfficeTeam.residentID(for: "data-analyst"), room: .researchRoom, status: .idle, role: "data-analyst")
        let placements = plan.placements(for: [resident, analyst] + extras)

        #expect(placements[resident.id]?.isSeated == true)
        #expect(extras.allSatisfy { placements[$0.id]?.isSeated == false })
        let points = placements.values.map(\.point)
        for (i, a) in points.enumerated() {
            for b in points[(i + 1)...] {
                #expect(hypot(a.x - b.x, a.y - b.y) >= FloorPlan3D.personSpacing - 0.001, "\(a) \(b)")
            }
        }
    }

    @Test func peopleWhoLeftAreNotPlaced() {
        #expect(plan.placements(for: [agent("gone", room: .desk, status: .left)]).isEmpty)
    }
}
