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

    /// The reward earned for a single transaction in the card's reward unit
    /// (cashback in the transaction currency, or miles). Returns `nil` for
    /// transactions on a card with `rewardType == .none` or with no card.
    static func reward(for transaction: Transaction) -> Decimal? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        return reward(amount: transaction.amount,
                      category: transaction.category,
                      card: card)
    }

    /// Pure-function variant — exposed for previews/tests where wiring up a
    /// SwiftData `Transaction` would be overkill.
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
    /// default currency. Use this for card-level cycle totals so mixed-currency
    /// spend (and the miles/cashback it earns) rolls up in a single currency.
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

    /// Uncapped total reward across the card's current billing cycle.
    private static func uncappedCycleReward(for card: Card) -> Decimal {
        guard card.rewardType != .none else { return 0 }
        return card.cycleTransactions
            .compactMap { convertedReward(for: $0) }
            .reduce(0, +)
    }

    /// Snapshot of a card's cycle reward standing against its cap, computed in a
    /// single pass over the cycle's transactions. Prefer this in views that need
    /// several of these values at once.
    struct CycleRewardStatus {
        /// Reward earned this cycle, clamped to the cap when one is set.
        let earned: Decimal
        /// The active cap; `0` means no cap.
        let cap: Decimal
        /// Uncapped earned reward — used to decide whether the cap is reached.
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
        let uncapped = uncappedCycleReward(for: card)
        let earned = cap > 0 ? min(uncapped, cap) : uncapped
        return CycleRewardStatus(earned: earned, cap: cap, uncapped: uncapped)
    }

    /// Aggregate of rewards across multiple transactions, bucketed by reward type.
    /// Miles are computed on amounts converted to the default currency (miles have no
    /// currency of their own, so mixed-currency spend must be normalised first).
    /// Cashback sums are in the *transaction's* currency — callers that mix currencies
    /// should already be FX-converting upstream.
    static func aggregate(_ transactions: [Transaction]) -> (miles: Decimal, cashback: Decimal) {
        var miles: Decimal = 0
        var cashback: Decimal = 0
        for tx in transactions {
            guard let card = tx.card, card.rewardType != .none else { continue }
            switch card.rewardType {
            case .miles:
                if let value = convertedReward(for: tx) { miles += value }
            case .cashback:
                if let value = reward(for: tx) { cashback += value }
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
        let reward: Decimal
        /// Currency the breakdown's amounts are denominated in. For miles this is the
        /// default currency (the amount is FX-converted before the rate is applied);
        /// for cashback it is the transaction's own currency.
        let currencyCode: String
        /// True when `amount` was FX-converted from the transaction's currency.
        var isConverted: Bool { currencyCode != transactionCurrency }
        let transactionCurrency: String
    }

    static func breakdown(for transaction: Transaction) -> Breakdown? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        // Miles have no currency of their own, so foreign spend is converted to the
        // default currency before the per-dollar rate is applied. Cashback stays in
        // the transaction's currency (the earned value is money in that currency).
        let amount: Decimal
        let currencyCode: String
        if card.rewardType == .miles {
            amount = transaction.amountInDefaultCurrency
            currencyCode = CurrencyUtils.rateToDefault(from: transaction.resolvedCurrency) != nil
                ? CurrencyUtils.defaultCurrencyCode
                : transaction.resolvedCurrency
        } else {
            amount = transaction.amount
            currencyCode = transaction.resolvedCurrency
        }
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
