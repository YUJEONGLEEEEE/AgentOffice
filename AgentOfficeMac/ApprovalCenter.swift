import AppKit
import AgentOfficeKit
import UserNotifications

/// The open permission questions, for the panel above the office.
@MainActor
@Observable
final class ApprovalPanelModel {
    var requests: [ApprovalRequest] = []
    var answer: (ApprovalRequest, ApprovalDecision) -> Void = { _, _ in }
}

/// Lets the user answer Claude Code's permission questions from the app.
///
/// While the app is open it marks itself alive, so the approval hook waits for an answer.
/// Each question shows in the panel and as a notification with Allow and Deny buttons.
/// The terminal question stays open the whole time; whichever answers first wins.
@MainActor
final class ApprovalCenter: NSObject {

    private static let refreshInterval: TimeInterval = 1
    private static let categoryID = "approval"
    private static let allowActionID = "allow"
    private static let denyActionID = "deny"

    let model = ApprovalPanelModel()
    /// Called when the list of questions changes, so the window can show or hide the panel.
    var onChange: (() -> Void)?

    private var folder: ApprovalFolder?
    private var timer: Timer?
    private var notifiedIDs: Set<String> = []
    private var askedForNotifications = false

    override init() {
        super.init()
        model.answer = { [weak self] request, decision in self?.answer(request, with: decision) }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let allow = UNNotificationAction(identifier: Self.allowActionID, title: String(localized: "Allow"))
        let deny = UNNotificationAction(identifier: Self.denyActionID, title: String(localized: "Deny"), options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: [allow, deny], intentIdentifiers: []),
        ])

        // Tell the hook right away when the app quits, so Claude Code never waits for a closed app.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.folder?.markClosed() }
        }
    }

    /// Starts answering in the given Approvals folder, or stops when there is none.
    func start(folderURL: URL?) {
        folder?.markClosed()
        timer?.invalidate()
        folder = folderURL.map(ApprovalFolder.init)
        guard folder != nil else {
            update([])
            return
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func answer(_ request: ApprovalRequest, with decision: ApprovalDecision) {
        try? folder?.answer(request, with: decision)
        update(model.requests.filter { $0.id != request.id })
    }

    private func refresh() {
        guard let folder else { return }
        try? folder.markAlive()
        update(folder.requests())
    }

    private func update(_ requests: [ApprovalRequest]) {
        let ids = Set(requests.map(\.id))
        // Questions answered in the terminal or here leave the notification list too.
        let gone = notifiedIDs.subtracting(ids)
        if !gone.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(gone))
            notifiedIDs.subtract(gone)
        }
        for request in requests where !notifiedIDs.contains(request.id) {
            notifiedIDs.insert(request.id)
            notify(request)
        }
        guard requests != model.requests else { return }
        model.requests = requests
        onChange?()
    }

    private func notify(_ request: ApprovalRequest) {
        let center = UNUserNotificationCenter.current()
        if !askedForNotifications {
            askedForNotifications = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(request.agentName) is waiting for your permission")
        content.subtitle = "\(request.project) · \(request.tool)"
        content.body = request.summary
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["id": request.id]
        center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: nil))
    }

    fileprivate func handle(actionID: String, requestID: String) {
        guard let request = model.requests.first(where: { $0.id == requestID }) else { return }
        switch actionID {
        case Self.allowActionID:
            answer(request, with: .allow)
        case Self.denyActionID:
            answer(request, with: .deny)
        default:
            // Clicking the notification itself opens the window, where the question is waiting.
            NSApp.activate()
        }
    }
}

extension ApprovalCenter: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let actionID = response.actionIdentifier
        guard let requestID = response.notification.request.content.userInfo["id"] as? String else { return }
        await MainActor.run { handle(actionID: actionID, requestID: requestID) }
    }

    /// The panel already shows the question while the window is in front.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}
