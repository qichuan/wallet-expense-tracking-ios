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
import WidgetKit

@available(iOS 16.0, *)
struct WalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Wallet Transaction"
    static var description = IntentDescription("Automatically log a transaction from Wallet")
    
    @Parameter(title: "Merchant Name")
    var merchantName: String

    /// Raw amount string from Apple Wallet, e.g. "S$12.50", "MYR 8.00", "$4.99"
    @Parameter(title: "Amount")
    var amount: String

    @Parameter(title: "Card Name")
    var cardName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction from \(\.$merchantName) for \(\.$amount) using \(\.$cardName)")
    }

    func perform() async throws -> some IntentResult {
        // Parse currency and numeric value from the raw amount string
        guard let (resolvedCurrency, decimalAmount) = await CurrencyUtils.parseCurrencyAndAmount(from: amount),
              decimalAmount != 0 else {
            return .result()
        }

        // Persist a new Transaction into SwiftData. Must match the main app's
        // schema + migration plan so the intent can open the same store on a
        // user who has already migrated to V3.
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self])
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CardPulseMigrationPlan.self
        )
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
                    minimumSpendingAmount: 0,
                    hasMinimumSpending: false,
                    rewardType: .none
                )
                context.insert(newCard)
                matchedCard = newCard
            }
        }

        let inferred = await CategoryInference.infer(
            merchantName: merchantName,
            amount: decimalAmount,
            currency: resolvedCurrency,
            cardName: matchedCard?.name,
            in: context
        )
        let guessedCategory = inferred.category
        // Best-effort: record where the tap-to-pay happened when location is authorized.
        // Returns nil quickly if permission is off or no fix is available.
        let location = await LocationManager.capture()
        let txn = Transaction(
            merchant: merchantName,
            amount: decimalAmount,
            date: Date(),
            category: guessedCategory,
            note: nil,
            card: matchedCard,
            currency: resolvedCurrency,
            latitude: location?.latitude,
            longitude: location?.longitude,
            placeName: location?.placeName
        )
        context.insert(txn)
        // current spent is derived from transactions; no direct mutation
        await AnalyticsTracker.log("add_wallet_transaction", [
            "type": "ttp",
            "merchant": merchantName,
            "currency": resolvedCurrency,
            "amount": amount,
            "category_source": inferred.source.rawValue
        ])
        do {
            try context.save()
            await WidgetDataWriter.refresh(using: context)
        } catch {
            // Swallow — the intent should never surface save errors to the user
        }

        // Notify user about the new transaction
        await notifyUserAboutNewTransaction(
            transactionId: txn.id,
            merchant: merchantName,
            amount: decimalAmount,
            currencyCode: resolvedCurrency,
            cardName: matchedCard?.name
        )

        return .result()
    }
    
    private func notifyUserAboutNewTransaction(transactionId: UUID, merchant: String, amount: Decimal, currencyCode: String, cardName: String?) async {
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
        formatter.currencyCode = currencyCode
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        let title = "Transaction Added"
        let cardSuffix = (cardName?.isEmpty == false) ? " on \(cardName!)" : ""
        let body = "\(merchant): \(amountString)\(cardSuffix)"
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [NotificationRouter.transactionIdUserInfoKey: transactionId.uuidString]
        
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
