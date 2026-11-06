import Darwin
import Foundation

/// Identifies a project folder by its volume and file number, which stay the same when the folder is renamed.
///
/// The hook records these two numbers instead of the folder's path, so no path is ever stored.
public struct ProjectFolderID: Hashable, Codable, Sendable {
    /// The volume the folder is on (`st_dev`).
    public let device: Int32
    /// The folder's file number on that volume (`st_ino`).
    public let inode: UInt64

    public init(device: Int32, inode: UInt64) {
        self.device = device
        self.inode = inode
    }

    /// The ID of a folder that exists now, or nil.
    public init?(folderAt url: URL) {
        var info = stat()
        guard stat(url.path(percentEncoded: false), &info) == 0, info.st_mode & S_IFMT == S_IFDIR else { return nil }
        self.init(device: info.st_dev, inode: info.st_ino)
    }
}

/// Where a project folder is now.
public enum ProjectFolderState: Equatable, Sendable {
    /// The folder exists, with this name (it may have been renamed).
    case present(name: String)
    /// The folder was deleted or moved to the Trash.
    case removed
}

public enum ProjectFolders {

    /// Looks up a folder by its ID. Returns nil when the system cannot tell, so nothing is hidden by mistake.
    ///
    /// This only reads file metadata, which the App Sandbox allows without access to the folder's contents.
    public static func state(of id: ProjectFolderID) -> ProjectFolderState? {
        var fsid = fsid_t(val: (id.device, 0))
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fsgetpath(&buffer, buffer.count, &fsid, id.inode) > 0 else {
            return errno == ENOENT ? .removed : nil
        }
        let path = String(cString: buffer)

        // A folder in the Trash is as good as deleted.
        if path.contains("/.Trash/") || path.contains("/.Trashes/") {
            return .removed
        }
        // The number may have been reused by a file after the folder was deleted.
        var info = stat()
        guard stat(path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            return .removed
        }
        return .present(name: URL(filePath: path).lastPathComponent)
    }
}

extension AgentSession {

    /// The session after checking its project folder: renamed if the folder was renamed,
    /// nil if the folder was deleted. Sessions recorded without a folder ID stay as they are.
    public func followingProjectFolder(
        _ resolve: (ProjectFolderID) -> ProjectFolderState? = ProjectFolders.state(of:)
    ) -> AgentSession? {
        guard let folder = projectFolder, let state = resolve(folder) else { return self }
        switch state {
        case .removed:
            return nil
        case .present(let name):
            var session = self
            session.renameProject(to: name)
            return session
        }
    }
}

extension ActivityEntry {

    /// The same entry on another floor, for a project folder that was renamed.
    public func onFloor(_ floor: String) -> ActivityEntry {
        ActivityEntry(id: id, time: time, agentID: agentID, agentName: agentName, floor: floor, room: room, status: status)
    }
}
