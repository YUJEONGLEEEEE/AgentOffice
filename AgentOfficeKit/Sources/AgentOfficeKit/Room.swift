import Foundation

/// A room in the office. Each room stands for a kind of work.
public enum Room: String, CaseIterable, Codable, Sendable {
    /// The agent's own desk: arriving, receiving work, or using a tool with no dedicated room.
    case desk
    /// Reading and searching files.
    case archive
    /// Writing and editing code.
    case devRoom
    /// Running commands and git.
    case serverRoom
    /// Searching the web.
    case researchRoom
    /// Planning and delegating work.
    case meetingRoom
    /// Taking a coffee break after finishing a reply.
    case breakRoom

    /// Maps a tool name from a `PreToolUse` event to the room where that work happens.
    public init(tool: String) {
        switch tool {
        case "Read", "Grep", "Glob", "LS":
            self = .archive
        case "Edit", "Write", "MultiEdit", "NotebookEdit":
            self = .devRoom
        case "Bash", "BashOutput", "KillShell":
            self = .serverRoom
        case "WebSearch", "WebFetch":
            self = .researchRoom
        case "TodoWrite", "Task", "Agent", "EnterPlanMode", "ExitPlanMode":
            self = .meetingRoom
        default:
            self = .desk
        }
    }

    public var displayName: String {
        switch self {
        case .desk: String(localized: "Desk", bundle: .module)
        case .archive: String(localized: "Archive", bundle: .module)
        case .devRoom: String(localized: "Dev Room", bundle: .module)
        case .serverRoom: String(localized: "Server Room", bundle: .module)
        case .researchRoom: String(localized: "Research Room", bundle: .module)
        case .meetingRoom: String(localized: "Meeting Room", bundle: .module)
        case .breakRoom: String(localized: "Break Room", bundle: .module)
        }
    }
}
