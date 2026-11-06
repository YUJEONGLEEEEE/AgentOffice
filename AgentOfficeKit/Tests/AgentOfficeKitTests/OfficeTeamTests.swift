import CoreGraphics
import Foundation
import Testing
@testable import AgentOfficeKit

struct OfficeTeamTests {

    private let layout = OfficeLayout.standard
    private let now = Date(timeIntervalSince1970: 1_793_862_600)

    private func job(_ id: String, role: String, room: Room = .archive, status: AgentStatus = .working,
                     minutesAgo: Double = 0) -> AgentSnapshot {
        AgentSnapshot(id: id, name: "\(TeamRole(agentType: role).title) · eebe", floor: "AgentOffice", room: room,
                      status: status, lastActivity: now.addingTimeInterval(-minutesAgo * 60), role: role)
    }

    @Test func everyTeamMemberHasASeatOnFreeFloorInTheirRoom() throws {
        for role in OfficeTeam.roster {
            let seat = try #require(layout.seat(forAgentType: role.agentType), "\(role.agentType)")
            #expect(layout.interior(for: seat.room).contains(seat.point), "\(role.agentType)")
            #expect(layout.isWalkable(seat.point), "\(role.agentType) seat is on furniture")
        }
    }

    @Test func seatsDoNotOverlapEachOtherOrVisitorSpots() throws {
        let seats = OfficeTeam.roster.compactMap { layout.seat(forAgentType: $0.agentType)?.point }
        for (index, seat) in seats.enumerated() {
            for other in seats[(index + 1)...] {
                #expect(hypot(seat.x - other.x, seat.y - other.y) >= 50, "\(seat) is too close to \(other)")
            }
            for room in Room.allCases {
                let spot = layout.spot(for: room)
                #expect(hypot(seat.x - spot.x, seat.y - spot.y) >= 50, "\(seat) is on the \(room) spot")
            }
        }
    }

    @Test(arguments: OfficeTeam.roster.map(\.agentType))
    func membersWalkFromTheirSeatToEveryRoomAroundFurniture(agentType: String) throws {
        let seat = try #require(layout.seat(forAgentType: agentType)).point
        for room in Room.allCases {
            let target = layout.spot(for: room)
            let points = [seat] + layout.path(from: seat, to: target)
            #expect(points.last == target)
            for (from, to) in zip(points, points.dropFirst()) {
                let steps = max(1, Int(hypot(to.x - from.x, to.y - from.y)))
                let blocked = (0...steps).contains { step in
                    let t = CGFloat(step) / CGFloat(steps)
                    return !layout.isWalkable(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
                }
                #expect(!blocked, "\(agentType) → \(room): \(from) → \(to)")
            }
        }
    }

    @Test func wholeTeamWaitsAtTheirDesksWithNoWork() {
        let arranged = OfficeTeam.arrange([])

        #expect(arranged.count == 9)
        #expect(arranged.allSatisfy { $0.status == .idle })
        #expect(arranged.map(\.name).contains("리서처"))
    }

    @Test func memberWithWorkKeepsTheirCharacter() throws {
        let arranged = OfficeTeam.arrange([job("eebe.a1", role: "market-researcher", room: .researchRoom)])
        let researcher = try #require(arranged.first { $0.role == "market-researcher" })

        #expect(arranged.count == 9)
        #expect(researcher.id == OfficeTeam.residentID(for: "market-researcher"))
        #expect(researcher.status == .working)
        #expect(researcher.room == .researchRoom)
        #expect(researcher.name == "리서처 · eebe")
    }

    @Test func extraJobsForTheSameMemberAppearAsExtraCharacters() {
        let arranged = OfficeTeam.arrange([
            job("eebe.a1", role: "qa-reviewer", minutesAgo: 1),
            job("e404.b2", role: "qa-reviewer", minutesAgo: 0),
        ])

        #expect(arranged.count == 10)
        #expect(arranged.contains { $0.id == OfficeTeam.residentID(for: "qa-reviewer") })
        #expect(arranged.contains { $0.id == "eebe.a1" })
    }

    @Test func leadersAndHelpersOutsideTheTeamStay() {
        let leader = AgentSnapshot(id: "eebe", name: "eebe", floor: "AgentOffice", room: .meetingRoom,
                                   status: .working, lastActivity: now)
        let arranged = OfficeTeam.arrange([leader, job("eebe.x", role: "Explore")])

        #expect(arranged.count == 11)
        #expect(arranged.contains(leader))
        #expect(arranged.contains { $0.id == "eebe.x" })
    }
}
