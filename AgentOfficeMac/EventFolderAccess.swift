import AppKit

/// Keeps access to the AgentOffice folder the user picked.
///
/// The app is sandboxed, so it can only use a folder the user chose in an open panel.
/// It reads the event logs in `Events` and writes answers to permission questions in `Approvals`.
/// Earlier versions asked for the `Events` folder itself; that still works, without approvals.
/// A security-scoped bookmark lets the app reopen that folder after relaunch without asking again.
final class EventFolderAccess {

    private let bookmarkKey = "eventFolderBookmark"
    private(set) var folderURL: URL?

    /// The folder the hook scripts write to.
    static var defaultFolderURL: URL {
        // Inside the sandbox, NSHomeDirectory() points to the app container, so read the real home folder.
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(filePath: home, directoryHint: .isDirectory)
            .appending(path: "Library/Application Support/AgentOffice", directoryHint: .isDirectory)
    }

    /// True when the user picked only the Events folder, as earlier versions asked.
    var choseOnlyEvents: Bool {
        folderURL?.lastPathComponent == "Events"
    }

    /// Where the event logs are.
    var eventsURL: URL? {
        guard let folderURL else { return nil }
        return choseOnlyEvents ? folderURL : folderURL.appending(path: "Events", directoryHint: .isDirectory)
    }

    /// Where the app answers permission questions. Nil when only the Events folder was chosen.
    var approvalsURL: URL? {
        guard let folderURL, !choseOnlyEvents else { return nil }
        return folderURL.appending(path: "Approvals", directoryHint: .isDirectory)
    }

    /// Reopens the folder saved last time. Returns nil when there is none or it can no longer be opened.
    @discardableResult
    func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ),
            url.startAccessingSecurityScopedResource()
        else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }

        if isStale {
            saveBookmark(for: url)
        }
        replaceFolder(with: url)
        return url
    }

    /// Shows an open panel attached to the window and remembers the chosen folder.
    func chooseFolder(for window: NSWindow, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Self.defaultFolderURL
        panel.message = String(localized: "Choose the AgentOffice folder. The app reads activity from it and saves your answers to permission questions there.")
        panel.prompt = String(localized: "Choose")

        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            _ = url.startAccessingSecurityScopedResource()
            self.saveBookmark(for: url)
            self.replaceFolder(with: url)
            completion(url)
        }
    }

    private func saveBookmark(for url: URL) {
        let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    private func replaceFolder(with url: URL) {
        if let folderURL, folderURL != url {
            folderURL.stopAccessingSecurityScopedResource()
        }
        folderURL = url
    }
}
