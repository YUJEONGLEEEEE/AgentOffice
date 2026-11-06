import Foundation
import Testing
@testable import AgentOfficeKit

struct ProjectFolderTests {

    private let start = Date(timeIntervalSince1970: 1_793_862_600)

    /// A new empty folder in the temporary directory.
    private func makeFolder(_ name: String) throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appending(path: "ProjectFolderTests-\(UUID().uuidString)")
        let folder = parent.appending(path: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func session(folder: ProjectFolderID?, project: String = "AgentOffice") throws -> AgentSession {
        try #require(AgentSession(events: [
            AgentEvent(timestamp: start, kind: .sessionStart, sessionID: "s1", project: project, projectFolder: folder),
            AgentEvent(timestamp: start.addingTimeInterval(1), kind: .preToolUse, sessionID: "s1", project: project,
                       tool: "Read", projectFolder: folder),
        ]))
    }

    // MARK: - Reading the log

    @Test func readsTheFolderIDFromTheLog() throws {
        let line = #"{"ts":"2026-11-05T07:10:12Z","event":"Stop","session":"s1","project":"A","projectDevice":16777234,"projectInode":88113835}"#
        let event = try #require(AgentEvent.parseLog(line).first)

        #expect(event.projectFolder == ProjectFolderID(device: 16_777_234, inode: 88_113_835))
    }

    @Test func olderLinesWithoutAFolderIDStillWork() throws {
        let line = #"{"ts":"2026-11-05T07:10:12Z","event":"Stop","session":"s1","project":"A"}"#
        let event = try #require(AgentEvent.parseLog(line).first)

        #expect(event.projectFolder == nil)
        #expect(event.project == "A")
    }

    @Test func aBrokenFolderIDDoesNotHideTheEvent() throws {
        let line = #"{"ts":"2026-11-05T07:10:12Z","event":"Stop","session":"s1","project":"A","projectDevice":"x","projectInode":-1}"#
        let event = try #require(AgentEvent.parseLog(line).first)

        #expect(event.projectFolder == nil)
        #expect(event.kind == .stop)
    }

    // MARK: - Real folders

    @Test func findsAFolderByItsID() throws {
        let folder = try makeFolder("2026 공모전")
        let id = try #require(ProjectFolderID(folderAt: folder))

        #expect(ProjectFolders.state(of: id) == .present(name: "2026 공모전"))
    }

    @Test func followsARenamedFolder() throws {
        let folder = try makeFolder("Old Name")
        let id = try #require(ProjectFolderID(folderAt: folder))
        try FileManager.default.moveItem(at: folder, to: folder.deletingLastPathComponent().appending(path: "New Name"))

        #expect(ProjectFolders.state(of: id) == .present(name: "New Name"))
    }

    @Test func noticesADeletedFolder() throws {
        let folder = try makeFolder("Gone")
        let id = try #require(ProjectFolderID(folderAt: folder))
        try FileManager.default.removeItem(at: folder)

        #expect(ProjectFolders.state(of: id) == .removed)
    }

    @Test func aFileIsNotAProjectFolder() throws {
        let folder = try makeFolder("Folder")
        let file = folder.appending(path: "notes.txt")
        try Data("hi".utf8).write(to: file)

        #expect(ProjectFolderID(folderAt: file) == nil)
    }

    // MARK: - Sessions

    @Test func sessionRemembersItsFolder() throws {
        let id = ProjectFolderID(device: 1, inode: 42)
        #expect(try session(folder: id).projectFolder == id)
    }

    @Test func renamedFolderMovesTheSession() throws {
        let id = ProjectFolderID(device: 1, inode: 42)
        let moved = try session(folder: id).followingProjectFolder { _ in .present(name: "AgentOffice2") }

        #expect(moved?.project == "AgentOffice2")
    }

    @Test func deletedFolderRemovesTheSession() throws {
        let id = ProjectFolderID(device: 1, inode: 42)
        #expect(try session(folder: id).followingProjectFolder { _ in .removed } == nil)
    }

    @Test func sessionKeepsItsFloorWhenTheSystemCannotTell() throws {
        let id = ProjectFolderID(device: 1, inode: 42)
        #expect(try session(folder: id).followingProjectFolder { _ in nil }?.project == "AgentOffice")
    }

    @Test func olderSessionsWithoutAFolderStayAsTheyAre() throws {
        let moved = try session(folder: nil).followingProjectFolder { _ in .removed }
        #expect(moved?.project == "AgentOffice")
    }

    @Test func teamMembersMoveWithTheirLeader() throws {
        var recorded = try session(folder: ProjectFolderID(device: 1, inode: 42))
        recorded.apply(AgentEvent(timestamp: start.addingTimeInterval(2), kind: .subagentStart, sessionID: "s1",
                                  project: "AgentOffice", agentID: "a1", agentType: "market-researcher"))
        let moved = try #require(recorded.followingProjectFolder { _ in .present(name: "Renamed") })

        #expect(moved.snapshots(at: start.addingTimeInterval(3)).allSatisfy { $0.floor == "Renamed" })
    }

    @Test func activityMovesToTheNewFloor() {
        let entry = ActivityEntry(id: "x", time: start, agentID: "s1", agentName: "s1", floor: "Old", room: .archive, status: .working)
        let moved = entry.onFloor("New")

        #expect(moved.floor == "New")
        #expect(moved.id == entry.id && moved.room == entry.room && moved.status == entry.status)
    }
}
