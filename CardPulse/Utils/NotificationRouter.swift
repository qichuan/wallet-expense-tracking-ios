//
//  NotificationRouter.swift
//  CardPulse
//

import Foundation
import UserNotifications
import Combine

/// Routes user-notification taps into the SwiftUI view layer. Set as the
/// `UNUserNotificationCenter` delegate at launch; views observe
/// `pendingTransactionId` and present the corresponding transaction.
@MainActor
final class NotificationRouter: NSObject, ObservableObject {
    static let shared = NotificationRouter()

    /// Set when the user taps a "Transaction Added" notification. Views
    /// consume this and reset it to nil after handling.
    @Published var pendingTransactionId: UUID?

    /// Set when the user taps a cycle nudge notification (min-spend / cap).
    /// Views consume this and reset it to nil after handling.
    @Published var pendingCardId: UUID?

    nonisolated static let transactionIdUserInfoKey = "transactionId"
    nonisolated static let cardIdUserInfoKey = "cardId"

    private override init() { super.init() }
}

extension NotificationRouter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let transactionId = (userInfo[NotificationRouter.transactionIdUserInfoKey] as? String)
            .flatMap(UUID.init(uuidString:))
        let cardId = (userInfo[NotificationRouter.cardIdUserInfoKey] as? String)
            .flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            if let transactionId {
                NotificationRouter.shared.pendingTransactionId = transactionId
            }
            if let cardId {
                NotificationRouter.shared.pendingCardId = cardId
            }
            completionHandler()
        }
    }
}
