//
//  RewardCalculator.swift
//  CardPulse
//

import Foundation

/// Computes rewards earned from transactions based on a card's configured rules.
///
/// The formula matches Singapore-bank conventions:
///
///   reward = floor(amount / roundingBlock) * roundingBlock * effectiveRate
///
/// where `effectiveRate` is the card's base rate plus any matching category bonus
/// rate (e.g. base 0.5% + Groceries bonus 5% = 5.5%).
/// For cashback the rate is treated as a percent (`1.6` → 1.6%); for miles the rate
/// is miles-per-dollar (`1.4` → 1.4 mpd).
enum RewardCalculator {

    /// Pure reward formula on an already-resolved amount — exposed for previews/tests
    /// where wiring up a SwiftData `Transaction` would be overkill. App surfaces must
    /// not apply this to a raw transaction amount; use `convertedReward(for:)`, which
    /// FX-converts first (issue #36).
    static func reward(amount: Decimal, category: String?, card: Card) -> Decimal? {
        guard card.rewardType != .none else { return nil }
        let rounded = roundDown(amount, toBlock: card.roundingBlock)
        let rate = effectiveRate(card: card, category: category)
        switch card.rewardType {
        case .cashback:
            return rounded * rate / 100
        case .miles:
            return rounded * rate
        case .none:
            return nil
        }
    }

    /// Reward for a transaction, computed on the amount converted to the user's
    /// default currency (convert → block-round → rate). The canonical per-transaction
    /// reward — every app surface (rows, summaries, cycle totals) goes through this,
    /// so mixed-currency spend always rolls up in a single currency. Returns `nil`
    /// for transactions on a card with `rewardType == .none` or with no card.
    static func convertedReward(for transaction: Transaction) -> Decimal? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        return reward(amount: transaction.amountInDefaultCurrency,
                      category: transaction.category,
                      card: card)
    }

    /// Total reward earned in the card's current billing cycle, computed on
    /// amounts converted to the default currency, capped at the configured limit.
    static func cycleReward(for card: Card) -> Decimal {
        cycleRewardStatus(for: card).earned
    }

    /// The active cap for a card's current reward type. Returns `0` when no cap is set.
    static func activeCap(for card: Card) -> Decimal {
        switch card.rewardType {
        case .miles:    return card.maxMilesCap
        case .cashback: return card.maxCashbackCap
        case .none:     return 0
        }
    }

    /// Total reward across the card's current billing cycle **after** applying each
    /// category's per-calendar-month cap (but before the card-wide cycle cap).
    private static func categoryCappedCycleReward(for card: Card) -> Decimal {
        guard card.rewardType != .none else { return 0 }
        let effective = categoryCappedRewards(for: card)
        return card.cycleTransactions.reduce(0) { $0 + (effective[$1.id] ?? 0) }
    }

    /// The per-category calendar-month cap for `category` on this card, or `nil` when the
    /// category has no rule or its rule sets no cap (`maxRewardCap <= 0`). Case-insensitive.
    static func monthlyCategoryCap(for card: Card, category: String?) -> Decimal? {
        guard let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let rule = card.rewardRules.first(where: { $0.categoryName.caseInsensitiveCompare(raw) == .orderedSame }),
              rule.maxRewardCap > 0
        else { return nil }
        return rule.maxRewardCap
    }

    /// Effective reward per transaction after applying per-category **calendar-month**
    /// caps, keyed by transaction `id`. Transactions in categories with no monthly cap
    /// pass through their uncapped `convertedReward`. Capped categories are bucketed by
    /// (category, calendar-month) and allocated chronologically, so earlier spend in the
    /// month consumes the cap first — this makes a cycle boundary that falls mid-month
    /// account correctly for spend earlier in the same month.
    ///
    /// Computed across the card's full transaction history (not just the current cycle).
    static func categoryCappedRewards(for card: Card) -> [UUID: Decimal] {
        guard card.rewardType != .none else { return [:] }
        var effective: [UUID: Decimal] = [:]
        var buckets: [String: [Transaction]] = [:]
        for tx in card.transactions {
            guard convertedReward(for: tx) != nil else { continue }
            if monthlyCategoryCap(for: card, category: tx.category) != nil {
                buckets[monthlyBucketKey(category: tx.category, date: tx.date), default: []].append(tx)
            } else {
                effective[tx.id] = convertedReward(for: tx) ?? 0
            }
        }
        for (_, txs) in buckets {
            let cap = monthlyCategoryCap(for: card, category: txs.first?.category) ?? 0
            var running: Decimal = 0
            for tx in txs.sorted(by: { $0.date < $1.date }) {
                let raw = convertedReward(for: tx) ?? 0
                let granted = min(raw, max(0, cap - running))
                effective[tx.id] = granted
                running += granted
            }
        }
        return effective
    }

    /// Groups transactions for per-category monthly capping: a case-insensitive category
    /// key plus the transaction's calendar year and month.
    private static func monthlyBucketKey(category: String?, date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let cat = (category ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(cat)|\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    /// Snapshot of a card's cycle reward standing against its cap, computed in a
    /// single pass over the cycle's transactions. Prefer this in views that need
    /// several of these values at once.
    struct CycleRewardStatus {
        /// Reward earned this cycle, clamped to the cap when one is set.
        let earned: Decimal
        /// The active cap; `0` means no cap.
        let cap: Decimal
        /// Earned reward after per-category monthly caps but before the card-wide cycle
        /// cap — used to decide whether the card-wide cap is reached.
        let uncapped: Decimal

        var hasCap: Bool { cap > 0 }
        var isCapReached: Bool { hasCap && uncapped >= cap }
        /// Reward remaining before the cap is hit; `nil` when no cap is set.
        var remaining: Decimal? { hasCap ? max(0, cap - earned) : nil }
        /// Progress toward the cap in `0...1`; `0` when no cap is set.
        var progress: Double {
            guard hasCap else { return 0 }
            let c = Double(truncating: cap as NSDecimalNumber)
            guard c > 0 else { return 0 }
            return min(1, Double(truncating: earned as NSDecimalNumber) / c)
        }
    }

    static func cycleRewardStatus(for card: Card) -> CycleRewardStatus {
        let cap = activeCap(for: card)
        // Per-category monthly caps are applied first; the card-wide cycle cap then
        // clamps the category-capped total on top.
        let uncapped = categoryCappedCycleReward(for: card)
        let earned = cap > 0 ? min(uncapped, cap) : uncapped
        return CycleRewardStatus(earned: earned, cap: cap, uncapped: uncapped)
    }

    /// Aggregate of rewards across multiple transactions, bucketed by reward type.
    /// Both buckets are computed on amounts converted to the default currency, so
    /// mixed-currency spend rolls up correctly: the cashback sum is denominated in
    /// the default currency.
    ///
    /// Per-category monthly caps are honoured: each transaction contributes its
    /// effective (category-capped) reward. Because a capped category's allowance is
    /// consumed by that card+category's spend across the whole calendar month, the
    /// effective value is computed against each card's full history — so a filtered
    /// range (a single day/week) reflects what those transactions actually earned once
    /// the monthly cap is taken into account.
    static func aggregate(_ transactions: [Transaction]) -> (miles: Decimal, cashback: Decimal) {
        var miles: Decimal = 0
        var cashback: Decimal = 0
        // Memoise each card's capped-reward map so it's computed once per card.
        var cappedByCard: [UUID: [UUID: Decimal]] = [:]
        for tx in transactions {
            guard let card = tx.card, card.rewardType != .none else { continue }
            let capped: [UUID: Decimal]
            if let cached = cappedByCard[card.id] {
                capped = cached
            } else {
                capped = categoryCappedRewards(for: card)
                cappedByCard[card.id] = capped
            }
            guard let value = capped[tx.id] else { continue }
            switch card.rewardType {
            case .miles: miles += value
            case .cashback: cashback += value
            case .none: break
            }
        }
        return (miles, cashback)
    }

    /// A step-by-step breakdown of how a transaction's reward was computed.
    /// Used by the transaction detail view to render an explanation table.
    struct Breakdown {
        let amount: Decimal
        let rounded: Decimal
        let roundingBlock: Decimal
        let effectiveRate: Decimal
        let baseRate: Decimal
        let bonusRate: Decimal
        let bonusCategory: String?
        let rewardType: RewardType
        /// Raw reward from the rate formula, before any per-category monthly cap.
        let reward: Decimal
        /// Reward after this transaction's category monthly cap has been applied.
        /// Equals `reward` when the category has no cap or the cap wasn't reached.
        let cappedReward: Decimal
        /// The category's per-calendar-month cap; `0` when the category has no cap.
        let monthlyCategoryCap: Decimal
        /// True when the monthly category cap limited this transaction's reward.
        var isCategoryCapReached: Bool { monthlyCategoryCap > 0 && cappedReward < reward }
        /// Currency the breakdown's amounts are denominated in: the default currency
        /// (the amount is FX-converted before the rate is applied), or the
        /// transaction's own currency when no rate is cached.
        let currencyCode: String
        /// True when `amount` was FX-converted from the transaction's currency.
        var isConverted: Bool { currencyCode != transactionCurrency }
        let transactionCurrency: String
    }

    static func breakdown(for transaction: Transaction) -> Breakdown? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        // Rewards are earned in the card's (default) currency, so foreign spend is
        // converted before the block rounding and rate are applied — for miles and
        // cashback alike. When no rate is cached the raw amount is used and the
        // breakdown keeps the transaction's currency label.
        let amount = transaction.amountInDefaultCurrency
        let currencyCode = CurrencyUtils.rateToDefault(from: transaction.resolvedCurrency) != nil
            ? CurrencyUtils.defaultCurrencyCode
            : transaction.resolvedCurrency
        let rounded = roundDown(amount, toBlock: card.roundingBlock)
        let raw = transaction.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bonus = card.rewardRules.first {
            !raw.isEmpty && $0.categoryName.caseInsensitiveCompare(raw) == .orderedSame
        }
        let effective = card.baseRewardRate + (bonus?.rate ?? 0)
        let reward: Decimal = {
            switch card.rewardType {
            case .cashback: return rounded * effective / 100
            case .miles:    return rounded * effective
            case .none:     return 0
            }
        }()
        // The effective reward after this transaction's category monthly cap. Falls back
        // to the raw reward if the transaction isn't found in the capped map (e.g. no cap).
        let cappedReward = categoryCappedRewards(for: card)[transaction.id] ?? reward
        return Breakdown(
            amount: amount,
            rounded: rounded,
            roundingBlock: card.roundingBlock,
            effectiveRate: effective,
            baseRate: card.baseRewardRate,
            bonusRate: bonus?.rate ?? 0,
            bonusCategory: bonus.map { $0.categoryName },
            rewardType: card.rewardType,
            reward: reward,
            cappedReward: cappedReward,
            monthlyCategoryCap: monthlyCategoryCap(for: card, category: transaction.category) ?? 0,
            currencyCode: currencyCode,
            transactionCurrency: transaction.resolvedCurrency
        )
    }

    // MARK: - Helpers

    private static func effectiveRate(card: Card, category: String?) -> Decimal {
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let rule = card.rewardRules.first(where: { $0.categoryName.caseInsensitiveCompare(raw) == .orderedSame }) {
            return card.baseRewardRate + rule.rate
        }
        return card.baseRewardRate
    }

    private static func roundDown(_ amount: Decimal, toBlock block: Decimal) -> Decimal {
        guard block > 0, block != 1 else { return amount }
        let amountNumber = amount as NSDecimalNumber
        let blockNumber = block as NSDecimalNumber
        let handler = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let blocks = amountNumber.dividing(by: blockNumber, withBehavior: handler)
        return blocks.multiplying(by: blockNumber) as Decimal
    }
}

// MARK: - Formatting

enum RewardFormatter {
    /// Formats a reward value using the card's reward type.
    /// Cashback is shown with the supplied currency symbol; miles get a localised "miles" suffix.
    static func format(_ value: Decimal, type: RewardType, currencySymbol: String) -> String {
        let n = Double(truncating: value as NSDecimalNumber)
        switch type {
        case .cashback:
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return "\(currencySymbol)\(f.string(from: NSNumber(value: n)) ?? "0.00")"
        case .miles:
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            let formatted = f.string(from: NSNumber(value: n)) ?? "0"
            return "\(formatted) miles"
        case .none:
            return ""
        }
    }
}
