//
//  WalletTransactionIntent.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import AppIntents
import SwiftData
import UserNotifications

@available(iOS 16.0, *)
struct WalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Wallet Transaction"
    static var description = IntentDescription("Automatically log a transaction from Wallet")
    
    @Parameter(title: "Merchant Name")
    var merchantName: String

    @Parameter(title: "Amount")
    var amount: Double
    
    @Parameter(title: "Card Name")
    var cardName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction from \(\.$merchantName) for \(\.$amount) using \(\.$cardName)")
    }
    
    func perform() async throws -> some IntentResult {
        // Persist a new Transaction into SwiftData
        let container = try ModelContainer(for: Card.self, Transaction.self)
        let context = ModelContext(container)

        // Find card by name or create it if missing
        var matchedCard: Card? = nil
        if !cardName.isEmpty {
            let cardRequest = FetchDescriptor<Card>(
                predicate: #Predicate { card in
                    card.name == cardName
                }
            )
            if let found = try? context.fetch(cardRequest).first {
                matchedCard = found
            } else {
                let newCard = Card(
                    name: cardName,
                    totalGoal: 0,
                    goalDeadline: Date(),
                    rewardType: "miles"
                )
                context.insert(newCard)
                matchedCard = newCard
            }
        }

        let decimalAmount = Decimal(Double(amount))
        let txn = Transaction(
            merchant: merchantName,
            amount: decimalAmount,
            date: Date(),
            category: nil,
            note: nil,
            card: matchedCard
        )
        context.insert(txn)
        if let matchedCard {
            matchedCard.currentSpent += decimalAmount
        }

        do {
            try context.save()
        } catch {
            // We intentionally swallow the error for the intent result to avoid user-facing failures
            // In production, consider logging via OSLog
        }

        // Notify user about the new transaction
        await notifyUserAboutNewTransaction(merchant: merchantName, amount: decimalAmount, cardName: matchedCard?.name)

        return .result()
    }

    private func notifyUserAboutNewTransaction(merchant: String, amount: Decimal, cardName: String?) async {
        let center = UNUserNotificationCenter.current()
        // Request authorization if not already granted
        do {
            if #available(iOS 17.0, *) {
                // Async/await native API
                _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } else {
                // Bridge the completion-handler API to async on iOS 16
                let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
                _ = granted
            }
        } catch {
            // Ignore authorization errors silently for intents
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        let title = "Transaction Added"
        let cardSuffix = (cardName?.isEmpty == false) ? " on \(cardName!)" : ""
        let body = "\(merchant): \(amountString)\(cardSuffix)"
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Fire quickly after intent completes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
        } catch {
            // Ignore notification errors silently for intents
        }
    }
}
