import Foundation
import AgentOfficeKit

/// Sends the office summary to iCloud so the iPhone app can show it.
///
/// It uploads only when something changed, at most every few seconds,
/// and sends a small heartbeat every minute so the iPhone knows the Mac is still on.
final class CloudPublisher {

    enum State: Equatable {
        case starting
        case syncing
        case accountUnavailable
        case failed
    }

    private static let minimumInterval: TimeInterval = 5
    private static let heartbeatInterval: TimeInterval = 60

    private let cloud = OfficeCloud()
    private var lastPublished: [AgentSnapshot]?
    private var lastSent: Date = .distantPast
    private var isSending = false
    private var hasLoadedPublishedIDs = false

    private(set) var state: State = .starting {
        didSet {
            if state != oldValue { onStateChange?(state) }
        }
    }
    var onStateChange: ((State) -> Void)?

    /// Call on every refresh with everyone in the office.
    func update(_ agents: [AgentSnapshot], now: Date) {
        guard !isSending else { return }
        let changed = agents != lastPublished
        let elapsed = now.timeIntervalSince(lastSent)
        guard (changed && elapsed >= Self.minimumInterval) || elapsed >= Self.heartbeatInterval else { return }

        isSending = true
        lastSent = now
        Task {
            do {
                if !hasLoadedPublishedIDs {
                    try await cloud.loadPublishedIDs()
                    hasLoadedPublishedIDs = true
                }
                if changed {
                    try await cloud.publish(agents, at: now)
                    lastPublished = agents
                } else {
                    try await cloud.sendHeartbeat(at: now)
                }
                state = .syncing
            } catch OfficeCloud.CloudError.accountUnavailable {
                state = .accountUnavailable
            } catch {
                state = .failed
            }
            isSending = false
        }
    }
}
