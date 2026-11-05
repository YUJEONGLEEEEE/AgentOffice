import Testing
@testable import AgentOfficeKit

struct RoomTests {

    @Test(arguments: [
        ("Read", Room.archive),
        ("Grep", .archive),
        ("Glob", .archive),
        ("Edit", .devRoom),
        ("Write", .devRoom),
        ("Bash", .serverRoom),
        ("WebSearch", .researchRoom),
        ("WebFetch", .researchRoom),
        ("TodoWrite", .meetingRoom),
        ("Agent", .meetingRoom),
    ])
    func mapsToolToRoom(tool: String, expected: Room) {
        #expect(Room(tool: tool) == expected)
    }

    @Test func unknownToolStaysAtDesk() {
        #expect(Room(tool: "mcp__notion__search") == .desk)
    }
}
