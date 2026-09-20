//
//  CategoryInference.swift
//  CardPulse
//

import Foundation
import SwiftData

/// Decides which spending category a freshly captured transaction belongs to.
///
/// Three tiers, cheapest and highest-signal first:
///
/// 1. **History** — the user already categorised this merchant, so reuse that.
/// 2. **Remote** — ask the category API (TypeSafe Jev) to choose among *all* of
///    the user's `SpendingCategory` records, custom ones included.
/// 3. **Heuristic** — local keyword rules, so a Wallet tap still gets a sensible
///    category with no network and no configuration.
///
/// Tier 2 replaced an `NLEmbedding` similarity match against hand-curated seed
/// words. Word vectors had no idea what an unfamiliar merchant actually sells;
/// a language model asked a single typed `choice` question does.
enum CategoryInference {

    /// Which tier produced the answer. Reported to analytics so the remote hit
    /// rate is visible without adding a second event.
    enum Source: String {
        case history
        case remote
        case heuristic
    }

    /// Below this, the remote answer is treated as a guess and we fall through
    /// to the keyword heuristic. Jev reports confidence as the concentration of
    /// its probability distribution; tune against real merchant strings before
    /// moving it.
    static let minimumConfidence: Double = 0.6

    /// A Wallet tap is waiting on this call, so the network budget is tight.
    private static let requestTimeout: TimeInterval = 4
    private static let resourceTimeout: TimeInterval = 6

    /// One category as the API sees it: the stored name plus a descriptive hint
    /// derived from its SF Symbol.
    ///
    /// A value type on purpose. `SpendingCategory` is a SwiftData model and not
    /// `Sendable`, so callers snapshot their records into these *before*
    /// suspending — nothing reaches across the await into the store.
    struct CategoryOption: Sendable, Hashable {
        let name: String
        let hint: String?
    }

    /// Snapshots stored categories for `remoteCategory`. Call on whichever actor
    /// owns the records (the main actor, for a SwiftUI form).
    static func options(from categories: [SpendingCategory]) -> [CategoryOption] {
        categories.map { CategoryOption(name: $0.name, hint: iconKeywords($0.icon)) }
    }

    // MARK: - Entry point

    /// Runs the cascade. Never throws and never returns an uncategorised
    /// transaction: the heuristic always yields at least `"Other"`.
    static func infer(
        merchantName: String,
        amount: Decimal? = nil,
        currency: String? = nil,
        cardName: String? = nil,
        in context: ModelContext
    ) async -> (category: String?, source: Source) {
        if let fromHistory = categoryFromHistory(merchantName: merchantName, in: context) {
            return (fromHistory, .history)
        }

        let categories = (try? context.fetch(
            FetchDescriptor<SpendingCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []

        if let fromRemote = await remoteCategory(
            merchantName: merchantName,
            amount: amount,
            currency: currency,
            cardName: cardName,
            options: options(from: categories)
        ) {
            return (fromRemote, .remote)
        }

        return (heuristicCategory(for: merchantName), .heuristic)
    }

    // MARK: - Tier 1: history

    /// Exact case-insensitive match wins; otherwise the most-recent substring
    /// match (bidirectional containment). Returns nil when no past transaction
    /// with a non-empty category matches — callers fall through to the API.
    static func categoryFromHistory(merchantName: String, in context: ModelContext) -> String? {
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

    // MARK: - Tier 2: remote

    /// Asks the category API to pick one of `options`.
    ///
    /// Returns nil — meaning "fall through to the heuristic" — when the app was
    /// built without API config, the request fails or times out, the response is
    /// unusable, confidence is below `minimumConfidence`, or the chosen name
    /// doesn't correspond to a stored category.
    static func remoteCategory(
        merchantName: String,
        amount: Decimal?,
        currency: String?,
        cardName: String?,
        options: [CategoryOption]
    ) async -> String? {
        let trimmedMerchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMerchant.isEmpty, !options.isEmpty else { return nil }
        guard let url = AppConfig.categoryAPIURL, let token = AppConfig.categoryAPIToken else { return nil }

        let names = options.map(\.name)
        let payload = RequestBody(
            merchant: trimmedMerchant,
            categories: options.map {
                RequestBody.Category(name: $0.name, hint: $0.hint)
            },
            amount: amount.map { NSDecimalNumber(decimal: $0).doubleValue },
            currency: currency,
            cardName: cardName
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = requestTimeout
        guard let body = try? JSONEncoder().encode(payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await sharedSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            return resolvedCategory(from: decoded, among: names)
        } catch {
            // Offline, timed out, or a malformed reply — the heuristic takes over.
            print("Category inference request failed: \(error)")
            return nil
        }
    }

    /// Applies the confidence gate and maps the API's answer back onto one of
    /// the category names we sent, returning that stored spelling.
    ///
    /// Returning the stored spelling matters: `MerchantUtils.normalizedCategory`
    /// collapses anything outside the seven built-ins to `"Other"`, so a custom
    /// category only survives if it is spelled exactly as stored.
    static func resolvedCategory(from response: ResponseBody, among names: [String]) -> String? {
        guard response.confidence >= minimumConfidence else { return nil }
        let candidate = response.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !candidate.isEmpty else { return nil }
        return names.first { $0.lowercased() == candidate }
    }

    private static let sharedSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // MARK: - Wire format

    struct RequestBody: Encodable {
        struct Category: Encodable {
            let name: String
            let hint: String?
        }
        let merchant: String
        let categories: [Category]
        let amount: Double?
        let currency: String?
        let cardName: String?
    }

    struct ResponseBody: Decodable {
        let category: String
        let confidence: Double
        let probabilities: [String: Double]?
        let model: String?
    }

    // MARK: - Tier 3: heuristic

    static func heuristicCategory(for merchant: String) -> String {
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

    // MARK: - Category hints

    /// Maps common SF Symbol names to descriptive English words, used as the
    /// per-option description the model sees alongside each category name.
    /// Unknown icons fall back to splitting the symbol's own name
    /// (e.g. "wrench.and.screwdriver" → "wrench and screwdriver"), which is
    /// usually descriptive in its own right. This is what lets a user's custom
    /// categories be classified as accurately as the built-ins.
    static func iconKeywords(_ icon: String) -> String {
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
            "cross": "health medical pharmacy",
            "cross.case": "pharmacy medical health",
            "stethoscope": "doctor medical clinic",
            "dumbbell": "gym fitness exercise",
            "scissors": "salon haircut barber",
            "wrench.and.screwdriver": "repair service maintenance",
            "book": "book reading education",
            "graduationcap": "education school tuition",
            "gift": "gift present shopping",
            "creditcard": "card payment",
            "dollarsign": "miscellaneous uncategorised spending",
            "star": "entertainment leisure fun",
            "fuelpump": "fuel gasoline car",
            "leaf": "grocery produce nature",
            "cart.badge.plus": "groceries supermarket"
        ]
        if let mapped = map[icon] { return mapped }
        return icon.replacingOccurrences(of: ".", with: " ")
    }
}
