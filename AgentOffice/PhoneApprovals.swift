import AgentOfficeKit
import CloudKit
import UIKit
import UserNotifications

extension Notification.Name {
    /// A question was answered or a new one arrived, so the office should load again.
    static let approvalsChanged = Notification.Name("approvalsChanged")
}

/// Lets the user answer Claude Code's permission questions on the iPhone.
///
/// iCloud sends a notification when the Mac puts a new question there.
/// It names the employee and the tool; the command shows only inside the app, where it is end-to-end encrypted.
/// Allow and Deny on the notification need the iPhone to be unlocked first.
@MainActor
final class PhoneApprovals: NSObject {

    static let shared = PhoneApprovals()

    private let cloud = OfficeCloud()
    private var isPrepared = false

    /// Call at launch, so actions on a notification that opened the app are handled.
    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let allow = UNNotificationAction(identifier: ApprovalNotification.allowActionID, title: String(localized: "Allow"),
                                         options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: ApprovalNotification.denyActionID, title: String(localized: "Deny"),
                                        options: [.authenticationRequired, .destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: ApprovalNotification.categoryID, actions: [allow, deny], intentIdentifiers: []),
        ])
    }

    /// Asks for notifications and signs up for new questions.
    /// Called once the office has loaded, so the request comes when the user can see what it is for.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            do {
                try await cloud.subscribeToApprovals()
            } catch {
                // Try again on the next launch.
                isPrepared = false
            }
        }
    }

    func answer(approvalID: String, with decision: ApprovalDecision) async {
        try? await cloud.answer(approvalID: approvalID, with: decision)
        NotificationCenter.default.post(name: .approvalsChanged, object: nil)
    }
}

extension PhoneApprovals: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let approvalID = (CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification)?
            .recordID?.recordName
        // Answer before returning: from the lock screen, the app may be suspended right after.
        switch (actionID, approvalID) {
        case (ApprovalNotification.allowActionID, let id?):
            await answer(approvalID: id, with: .allow)
        case (ApprovalNotification.denyActionID, let id?):
            await answer(approvalID: id, with: .deny)
        default:
            // Tapping the notification opens the app, where the question is waiting.
            await MainActor.run {
                NotificationCenter.default.post(name: .approvalsChanged, object: nil)
            }
        }
    }

    /// The panel shows the question while the app is open, so no banner; just load it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            NotificationCenter.default.post(name: .approvalsChanged, object: nil)
        }
        return []
    }
}
