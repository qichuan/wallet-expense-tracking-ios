//
//  NotificationRouter.swift
//  CardPulse
//

import Foundation
import UserNotifications

/// Routes user-notification taps into the SwiftUI view layer. Set as the
/// `UNUserNotificationCenter` delegate at launch; views observe
/// `pendingTransactionId` and present the corresponding transaction.
@MainActor
final class NotificationRouter: NSObject, ObservableObject {
    static let shared = NotificationRouter()

    /// Set when the user taps a "Transaction Added" notification. Views
    /// consume this and reset it to nil after handling.
    @Published var pendingTransactionId: UUID?

    nonisolated static let transactionIdUserInfoKey = "transactionId"

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
        let raw = userInfo[NotificationRouter.transactionIdUserInfoKey] as? String
        let id = raw.flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            if let id = id {
                NotificationRouter.shared.pendingTransactionId = id
            }
            completionHandler()
        }
    }
}
