import AgentOfficeKit
import CloudKit
import os
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
    private static let log = Logger(subsystem: "com.aspyn.AgentOffice", category: "approvals")

    private let cloud = OfficeCloud()
    private var isPrepared = false

    /// What happened to the push registration: nil while waiting, then success or the error.
    private var pushRegistration: Result<Void, Error>?
    /// The last thing that went wrong with notifications, for the status screen.
    private var lastError: String?

    /// Call at launch, so actions on a notification that opened the app are handled.
    /// The push registration does not need permission; only showing notifications does.
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
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegisterForPush() {
        pushRegistration = .success(())
        Self.log.notice("Registered for push notifications")
    }

    func didFailToRegisterForPush(_ error: Error) {
        pushRegistration = .failure(error)
        record("Push registration failed", error)
    }

    /// Asks for notifications and signs up for new questions.
    /// Called whenever the office shows, until the sign-up has worked once in this run.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        Task {
            do {
                try await cloud.subscribeToApprovals()
                Self.log.notice("Signed up for new questions")
            } catch {
                record("Could not sign up for new questions", error)
                isPrepared = false
            }
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                Self.log.notice("Notifications allowed: \(granted, privacy: .public)")
            } catch {
                record("Could not ask for notifications", error)
            }
        }
    }

    func answer(approvalID: String, with decision: ApprovalDecision) async {
        do {
            try await cloud.answer(approvalID: approvalID, with: decision)
        } catch {
            record("Could not send the answer", error)
        }
        NotificationCenter.default.post(name: .approvalsChanged, object: nil)
    }

    /// Clears notifications for questions that ended, so Allow is never pressed on a question that is gone.
    func removeNotifications(except openIDs: Set<String>) async {
        let center = UNUserNotificationCenter.current()
        let ended = await center.deliveredNotifications().filter { notification in
            guard let id = Self.approvalID(in: notification.request.content.userInfo) else { return false }
            return !openIDs.contains(id)
        }
        center.removeDeliveredNotifications(withIdentifiers: ended.map(\.request.identifier))
    }

    /// Lines for the notification status screen. Each part of the path a notification takes, in order.
    func statusLines() async -> [String] {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let permission = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "Allowed")
        case .denied: String(localized: "Not allowed")
        default: String(localized: "Not asked yet")
        }
        let lockScreen = settings.lockScreenSetting == .enabled ? String(localized: "On") : String(localized: "Off")
        let push = switch pushRegistration {
        case .success: String(localized: "Done")
        case .failure: String(localized: "Failed")
        case nil: String(localized: "Waiting")
        }
        let signUp: String
        do {
            signUp = try await cloud.hasApprovalSubscription() ? String(localized: "Done") : String(localized: "Missing")
        } catch {
            signUp = String(localized: "Couldn’t check")
            record("Could not check the sign-up", error)
        }
        var lines = [
            String(localized: "Permission: \(permission)"),
            String(localized: "Lock screen: \(lockScreen)"),
            String(localized: "Push registration: \(push)"),
            String(localized: "iCloud sign-up: \(signUp)"),
        ]
        if let lastError {
            lines.append(String(localized: "Last error: \(lastError)"))
        }
        return lines
    }

    private func record(_ message: String, _ error: Error) {
        let detail = (error as? CKError).map { "CKError \($0.code.rawValue): \($0.localizedDescription)" }
            ?? error.localizedDescription
        lastError = "\(message). \(detail)"
        Self.log.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
    }

    nonisolated private static func approvalID(in userInfo: [AnyHashable: Any]) -> String? {
        (CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification)?.recordID?.recordName
    }
}

extension PhoneApprovals: UNUserNotificationCenterDelegate {

    // These use completion handlers, called on the main thread. iOS stops the app if they are called
    // from another thread, which the async versions of these methods can do.

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        let approvalID = Self.approvalID(in: response.notification.request.content.userInfo)
        Self.log.notice("Notification answered: \(actionID, privacy: .public)")
        Task { @MainActor in
            // Answer before finishing: from the lock screen, the app may be suspended right after.
            switch (actionID, approvalID) {
            case (ApprovalNotification.allowActionID, let id?):
                await answer(approvalID: id, with: .allow)
            case (ApprovalNotification.denyActionID, let id?):
                await answer(approvalID: id, with: .deny)
            default:
                // Tapping the notification opens the app, where the question is waiting.
                NotificationCenter.default.post(name: .approvalsChanged, object: nil)
            }
            completionHandler()
        }
    }

    /// The panel shows the question while the app is open, so no banner; just load it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Self.log.notice("Notification arrived while the app is open")
        Task { @MainActor in
            NotificationCenter.default.post(name: .approvalsChanged, object: nil)
            completionHandler([])
        }
    }
}
