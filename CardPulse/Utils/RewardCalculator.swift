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
        guard card.rewardType != .none else { return 0 }
        let total = card.cycleTransactions
            .compactMap { convertedReward(for: $0) }
            .reduce(0, +)
        let cap = activeCap(for: card)
        guard cap > 0 else { return total }
        return min(total, cap)
    }

    /// The active cap for a card's current reward type. Returns `0` when no cap is set.
    static func activeCap(for card: Card) -> Decimal {
        switch card.rewardType {
        case .miles:    return card.maxMilesCap
        case .cashback: return card.maxCashbackCap
        case .none:     return 0
        }
    }

    /// Whether the card has reached its reward cap this cycle.
    static func isCapReached(for card: Card) -> Bool {
        let cap = activeCap(for: card)
        guard cap > 0 else { return false }
        let uncapped = card.cycleTransactions
            .compactMap { convertedReward(for: $0) }
            .reduce(0, +)
        return uncapped >= cap
    }

    /// Reward remaining before the cap is hit. Returns `nil` when no cap is configured.
    static func remainingUntilCap(for card: Card) -> Decimal? {
        let cap = activeCap(for: card)
        guard cap > 0 else { return nil }
        return max(0, cap - cycleReward(for: card))
    }

    /// Aggregate of rewards across multiple transactions, bucketed by reward type.
    /// Cashback sums are in the *transaction's* currency — callers that mix currencies
    /// should already be FX-converting upstream.
    static func aggregate(_ transactions: [Transaction]) -> (miles: Decimal, cashback: Decimal) {
        var miles: Decimal = 0
        var cashback: Decimal = 0
        for tx in transactions {
            guard let card = tx.card,
                  let value = reward(for: tx) else { continue }
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
        let reward: Decimal
    }

    static func breakdown(for transaction: Transaction) -> Breakdown? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        let rounded = roundDown(transaction.amount, toBlock: card.roundingBlock)
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
            amount: transaction.amount,
            rounded: rounded,
            roundingBlock: card.roundingBlock,
            effectiveRate: effective,
            baseRate: card.baseRewardRate,
            bonusRate: bonus?.rate ?? 0,
            bonusCategory: bonus.map { $0.categoryName },
            rewardType: card.rewardType,
            reward: reward
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
