/// A room in the office. Each room stands for a kind of work.
public enum Room: String, CaseIterable, Sendable {
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
        case .desk: "자기 자리"
        case .archive: "자료실"
        case .devRoom: "개발실"
        case .serverRoom: "서버실"
        case .researchRoom: "정보검색실"
        case .meetingRoom: "회의실"
        case .breakRoom: "탕비실"
        }
    }
}
