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
import NaturalLanguage
import FirebaseAnalytics
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
        guard let (resolvedCurrency, decimalAmount) = parseCurrencyAndAmount(from: amount),
              decimalAmount != 0 else {
            return .result()
        }

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
                    minimumSpendingAmount: 0,
                    hasMinimumSpending: false,
                    rewardType: .none
                )
                context.insert(newCard)
                matchedCard = newCard
            }
        }

        let guessedCategory = guessCategory(from: merchantName)
        let txn = Transaction(
            merchant: merchantName,
            amount: decimalAmount,
            date: Date(),
            category: guessedCategory,
            note: nil,
            card: matchedCard,
            currency: resolvedCurrency
        )
        context.insert(txn)
        // current spent is derived from transactions; no direct mutation
        Analytics.logEvent("add_wallet_transaction", parameters: [
            "type": "ttp",
            "merchant": merchantName,
            "currency": resolvedCurrency,
            "amount": amount,
        ])
        do {
            try context.save()
            // Refresh the widget after the intent saves new data
            let cardRequest = FetchDescriptor<Card>()
            if let allCards = try? context.fetch(cardRequest) {
                let spendData = allCards.map { card in
                    CardSpendData(
                        id: card.id,
                        name: card.name,
                        monthlySpent: Double(truncating: card.monthlySpent as NSDecimalNumber),
                        minimumSpending: Double(truncating: card.minimumSpendingAmount as NSDecimalNumber),
                        hasMinimumSpending: card.hasMinimumSpending,
                        daysRemaining: card.daysRemaining,
                        rewardType: card.rewardType.rawValue,
                        spendingPeriodDisplay: card.spendingPeriodDisplay
                    )
                }
                await WidgetDataWriter.write(spendData: spendData)
            }
        } catch {
            // We intentionally swallow the error for the intent result to avoid user-facing failures
            // In production, consider logging via OSLog
        }

        // Notify user about the new transaction
        await notifyUserAboutNewTransaction(merchant: merchantName, amount: decimalAmount, cardName: matchedCard?.name)

        return .result()
    }

    /// Parses a raw Wallet amount string (e.g. "S$12.50", "MYR 8.00", "$4.99")
    /// into a (currencyCode, amount) pair. Falls back to the user's default currency
    /// for ambiguous symbols like "$".
    private func parseCurrencyAndAmount(from raw: String) -> (String, Decimal)? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // Build symbol→code mapping dynamically from CurrencyUtils so new currencies
        // (including user-added custom ones) are supported automatically.
        let currencies = CurrencyUtils.allAvailableCurrencies
        var symbolToCode: [(String, String)] = []
        // 1. Unambiguous ISO code prefixes (e.g. "SGD 12.50", "MYR 8.00")
        symbolToCode += currencies.map { ($0.code, $0.code) }
        // 2. Currency symbols, longest first so "S$" is tried before "$".
        //    Use a stable sort (preserve original order for equal-length symbols)
        //    so JPY wins over CNY when both share "¥".
        let indexed = currencies.filter { $0.symbol != "$" }.enumerated().map { ($0.offset, $0.element) }
        let sortedBySymbolLength = indexed.sorted {
            if $0.1.symbol.count != $1.1.symbol.count { return $0.1.symbol.count > $1.1.symbol.count }
            return $0.0 < $1.0
        }
        symbolToCode += sortedBySymbolLength.map { ($0.1.symbol, $0.1.code) }
        // 3. "$" is ambiguous — map to the user's configured default currency
        symbolToCode.append(("$", CurrencyUtils.defaultCurrencyCode))

        for (symbol, code) in symbolToCode {
            // Prefix match (e.g. "MYR 8.00", "S$12.50")
            if trimmed.uppercased().hasPrefix(symbol.uppercased()) {
                let rest = String(trimmed.dropFirst(symbol.count)).trimmingCharacters(in: .whitespaces)
                if let amount = parseDecimal(from: rest) { return (code, amount) }
            }
            // Suffix match (e.g. "8.00 MYR")
            if trimmed.uppercased().hasSuffix(symbol.uppercased()) {
                let rest = String(trimmed.dropLast(symbol.count)).trimmingCharacters(in: .whitespaces)
                if let amount = parseDecimal(from: rest) { return (code, amount) }
            }
        }

        // No recognised symbol — try parsing as a bare number, use default currency
        if let amount = parseDecimal(from: trimmed) {
            return (CurrencyUtils.defaultCurrencyCode, amount)
        }
        return nil
    }

    private func parseDecimal(from string: String) -> Decimal? {
        // Strip thousand-separators before parsing
        let cleaned = string.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned)
    }

    private func guessCategory(from merchant: String) -> String? {
        let categories = MerchantUtils.defaultCategories
        // Seed words representing each category's semantics
        let seeds: [String: [String]] = [
            "Shopping": ["store", "retail", "mall", "outlet", "amazon", "shop"],
            "Food & Drinks": ["restaurant", "cafe", "bar", "food", "drink", "coffee", "diner"],
            "Services": ["service", "repair", "plumber", "cleaning", "subscription", "salon"],
            "Travel": ["airline", "hotel", "flight", "uber", "lyft", "train", "transport"],
            "Entertainment": ["movie", "cinema", "music", "concert", "game", "theater"],
            "Health": ["pharmacy", "clinic", "doctor", "dentist", "gym", "health"],
            "Other": ["payment", "misc", "general"]
        ]
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = merchant
        let range = merchant.startIndex..<merchant.endIndex
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let word = String(merchant[tokenRange]).lowercased()
            if !word.isEmpty { tokens.append(word) }
            return true
        }
        // If we have no embedding or tokens, fallback to keyword heuristics
        guard let embedding else {
            return heuristicCategory(for: merchant)
        }
        var bestCategory: String = "Other"
        var bestScore: Double = .greatestFiniteMagnitude // using distance: lower is better
        for category in categories {
            guard let seedWords = seeds[category] else { continue }
            var categoryBest: Double = .greatestFiniteMagnitude
            for token in tokens {
                // Ensure both words exist in the embedding
                guard embedding.contains(token) else { continue }
                for seed in seedWords {
                    guard embedding.contains(seed) else { continue }
                    let distance = embedding.distance(between: token, and: seed)
                    if distance < categoryBest { categoryBest = distance }
                }
            }
            if categoryBest < bestScore {
                bestScore = categoryBest
                bestCategory = category
            }
        }
        // Apply a loose threshold; if embedding can't relate, keep Other
        if bestScore > 1.2 { // empirically reasonable for unrelated words
            return "Other"
        }
        return bestCategory
    }

    private func heuristicCategory(for merchant: String) -> String {
        let lower = merchant.lowercased()
        let rules: [(String, String)] = [
            ("uber", "Travel"), ("lyft", "Travel"), ("airbnb", "Travel"), ("airlines", "Travel"),
            ("hotel", "Travel"), ("marriott", "Travel"), ("hilton", "Travel"), ("train", "Travel"),
            ("mcdonald", "Food & Drinks"), ("kfc", "Food & Drinks"), ("starbucks", "Food & Drinks"), ("subway", "Food & Drinks"), ("restaurant", "Food & Drinks"),
            ("pharmacy", "Health"), ("walgreens", "Health"), ("cvs", "Health"), ("clinic", "Health"),
            ("netflix", "Entertainment"), ("spotify", "Entertainment"), ("movie", "Entertainment"), ("cinema", "Entertainment"), ("game", "Entertainment"),
            ("amazon", "Shopping"), ("walmart", "Shopping"), ("target", "Shopping"), ("mall", "Shopping"), ("shop", "Shopping"),
            ("repair", "Services"), ("salon", "Services"), ("plumb", "Services"), ("clean", "Services"), ("service", "Services")
        ]
        for (keyword, category) in rules {
            if lower.contains(keyword) {
                return category
            }
        }
        return "Other"
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
