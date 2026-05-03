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
        guard let (resolvedCurrency, decimalAmount) = CurrencyUtils.parseCurrencyAndAmount(from: amount),
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

        let guessedCategory = inferCategory(merchantName: merchantName, in: context)
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
        AnalyticsTracker.log("add_wallet_transaction", [
            "type": "ttp",
            "merchant": merchantName,
            "currency": resolvedCurrency,
            "amount": amount
        ])
        do {
            try context.save()
            await WidgetDataWriter.refresh(using: context)
        } catch {
            // Swallow — the intent should never surface save errors to the user
        }

        // Notify user about the new transaction
        await notifyUserAboutNewTransaction(
            merchant: merchantName,
            amount: decimalAmount,
            currencyCode: resolvedCurrency,
            cardName: matchedCard?.name
        )

        return .result()
    }
    
    /// Top-level category inference. Tries past-transaction matching first
    /// (cheapest, highest-signal), then falls back to NL-embedding similarity
    /// against built-in *and* user-custom categories, then to a keyword
    /// heuristic if the embedding is unavailable.
    private func inferCategory(merchantName: String, in context: ModelContext) -> String? {
        if let fromHistory = categoryFromHistory(merchantName: merchantName, in: context) {
            return fromHistory
        }
        if let fromNL = guessCategoryViaNL(merchantName: merchantName, in: context) {
            return fromNL
        }
        return heuristicCategory(for: merchantName)
    }

    /// Exact case-insensitive match wins; otherwise the most-recent
    /// substring match (bidirectional containment). Returns nil when no
    /// past transaction with a non-empty category matches — callers should
    /// fall through to NL.
    private func categoryFromHistory(merchantName: String, in context: ModelContext) -> String? {
        let query = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return nil }

        var bestExact: String?
        var bestSubstring: String?
        for tx in all {
            let stored = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !stored.isEmpty,
                  let cat = tx.category,
                  !cat.isEmpty
            else { continue }

            if stored == query {
                if bestExact == nil { bestExact = cat }
            } else if stored.contains(query) || query.contains(stored) {
                if bestSubstring == nil { bestSubstring = cat }
            }
        }
        return bestExact ?? bestSubstring
    }

    /// Embedding-based similarity match. Builds seed-word sets per category:
    /// curated lists for the built-ins, plus name-tokens and SF Symbol
    /// keywords for any user-defined `SpendingCategory`. Scores each
    /// category by the *average* of best per-token distances (more stable
    /// than a single min — penalises categories that match only one noisy
    /// token), then picks the lowest-distance category if it passes a
    /// confidence threshold.
    private func guessCategoryViaNL(merchantName: String, in context: ModelContext) -> String? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }

        let stored = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        let allCategoryNames: [String] = stored.isEmpty
            ? MerchantUtils.defaultCategories
            : stored.map { $0.name }

        var seedsByCategory: [String: [String]] = [:]
        for name in allCategoryNames {
            var seeds = builtInSeeds[name] ?? []
            seeds.append(contentsOf: meaningfulTokens(in: name))
            if let custom = stored.first(where: { $0.name == name }) {
                seeds.append(contentsOf: meaningfulTokens(in: iconKeywords(custom.icon)))
            }
            // Dedup while preserving order
            var dedup: [String] = []
            var seen = Set<String>()
            for w in seeds where seen.insert(w).inserted { dedup.append(w) }
            if !dedup.isEmpty { seedsByCategory[name] = dedup }
        }

        let merchantTokens = meaningfulTokens(in: merchantName)
        guard !merchantTokens.isEmpty else { return nil }

        var bestCategory: String?
        var bestScore: Double = .greatestFiniteMagnitude
        for (cat, seeds) in seedsByCategory {
            var totalBest: Double = 0
            var counted = 0
            for token in merchantTokens where embedding.contains(token) {
                var tokenBest: Double = .greatestFiniteMagnitude
                for seed in seeds where embedding.contains(seed) {
                    let d = embedding.distance(between: token, and: seed)
                    if d < tokenBest { tokenBest = d }
                }
                if tokenBest < .greatestFiniteMagnitude {
                    totalBest += tokenBest
                    counted += 1
                }
            }
            guard counted > 0 else { continue }
            let avg = totalBest / Double(counted)
            if avg < bestScore {
                bestScore = avg
                bestCategory = cat
            }
        }

        // Confidence threshold tuned for word-embedding distances; below
        // this is a defensible match, above is closer to noise.
        return bestScore <= 0.95 ? bestCategory : nil
    }

    /// Curated seed words for the 7 built-in categories. Custom categories
    /// derive their seeds from the name + icon keywords instead.
    private var builtInSeeds: [String: [String]] {
        [
            "Shopping": ["store", "retail", "mall", "outlet", "shopping", "shop", "boutique", "market", "merchandise"],
            "Food & Drinks": ["restaurant", "cafe", "bar", "food", "drink", "coffee", "diner", "kitchen", "bistro", "eatery", "bakery"],
            "Services": ["service", "repair", "plumber", "cleaning", "subscription", "salon", "laundry", "barber", "maintenance"],
            "Travel": ["airline", "hotel", "flight", "transport", "taxi", "train", "rental", "travel", "lodging", "hostel"],
            "Entertainment": ["movie", "cinema", "music", "concert", "game", "theater", "streaming", "show"],
            "Health": ["pharmacy", "clinic", "doctor", "dentist", "gym", "health", "fitness", "medical", "hospital"],
            "Other": ["payment", "misc", "general", "unknown"]
        ]
    }

    /// Tokenises a string into lowercase letter-only words ≥3 chars long,
    /// dropping country codes, business suffixes, and other noise that
    /// distort embedding distances ("PTE LTD", "INC", "CO", "INTL", etc).
    private func meaningfulTokens(in s: String) -> [String] {
        let banned: Set<String> = [
            "ltd", "pte", "llc", "inc", "corp", "the", "and",
            "intl", "international", "asia", "sgp", "usa", "limited",
            "pay", "payment", "transaction"
        ]
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = s
        var out: [String] = []
        tokenizer.enumerateTokens(in: s.startIndex..<s.endIndex) { range, _ in
            let raw = String(s[range]).lowercased()
            let alpha = String(raw.filter { $0.isLetter })
            if alpha.count >= 3, !banned.contains(alpha) {
                out.append(alpha)
            }
            return true
        }
        return out
    }

    /// Maps common SF Symbol names to descriptive English words so the
    /// embedding has something to compare against. Unknown icons fall back
    /// to splitting the symbol's own name (e.g. "wrench.and.screwdriver" →
    /// "wrench and screwdriver"), which is often itself meaningful.
    private func iconKeywords(_ icon: String) -> String {
        let map: [String: String] = [
            "bag": "shopping bag",
            "bag.fill": "shopping bag",
            "cart": "shopping cart",
            "cart.fill": "shopping cart",
            "fork.knife": "food restaurant dining",
            "cup.and.saucer": "coffee drink cafe",
            "cup.and.saucer.fill": "coffee drink cafe",
            "wineglass": "wine drink bar",
            "airplane": "flight travel airline",
            "car": "car driving travel taxi",
            "car.fill": "car driving travel taxi",
            "tram": "train transit transport",
            "bus": "bus transport",
            "house": "home housing rent",
            "house.fill": "home housing rent",
            "tv": "television entertainment streaming",
            "gamecontroller": "game gaming entertainment",
            "music.note": "music streaming entertainment",
            "film": "movie cinema entertainment",
            "pawprint": "pet animal vet",
            "pawprint.fill": "pet animal vet",
            "heart": "health medical fitness",
            "heart.fill": "health medical fitness",
            "cross.case": "pharmacy medical health",
            "stethoscope": "doctor medical clinic",
            "dumbbell": "gym fitness exercise",
            "scissors": "salon haircut barber",
            "wrench.and.screwdriver": "repair service maintenance",
            "book": "book reading education",
            "graduationcap": "education school tuition",
            "gift": "gift present shopping",
            "creditcard": "card payment",
            "fuelpump": "fuel gasoline car",
            "leaf": "grocery produce nature",
            "cart.badge.plus": "groceries supermarket"
        ]
        if let mapped = map[icon] { return mapped }
        return icon.replacingOccurrences(of: ".", with: " ")
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
    private func notifyUserAboutNewTransaction(merchant: String, amount: Decimal, currencyCode: String, cardName: String?) async {
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
