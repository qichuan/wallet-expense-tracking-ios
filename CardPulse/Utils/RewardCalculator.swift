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
///
/// Currency-based rates *replace* the base rate (they don't stack with it):
/// a `CardCurrencyRule` matching the transaction's currency wins, else the card's
/// `foreignRewardRate` applies when the currency differs from the user's default,
/// else the base rate. Category bonuses still add on top of whichever applies.
enum RewardCalculator {

    /// The reward earned for a single transaction in the card's reward unit
    /// (cashback in the transaction currency, or miles). Returns `nil` for
    /// transactions on a card with `rewardType == .none` or with no card.
    static func reward(for transaction: Transaction) -> Decimal? {
        guard let card = transaction.card, card.rewardType != .none else { return nil }
        return reward(amount: transaction.amount,
                      category: transaction.category,
                      card: card,
                      currency: transaction.resolvedCurrency)
    }

    /// Pure-function variant — exposed for previews/tests where wiring up a
    /// SwiftData `Transaction` would be overkill. Pass `currency` to apply the
    /// card's currency-based rates; `nil` always uses the base rate.
    static func reward(amount: Decimal, category: String?, card: Card, currency: String? = nil) -> Decimal? {
        guard card.rewardType != .none else { return nil }
        let rounded = roundDown(amount, toBlock: card.roundingBlock)
        let rate = effectiveRate(card: card, category: category, currency: currency)
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
        // The rate is still driven by the original transaction currency — only the
        // amount it applies to is converted, mirroring how banks award FCY rates
        // on the converted amount posted to the statement.
        return reward(amount: transaction.amountInDefaultCurrency,
                      category: transaction.category,
                      card: card,
                      currency: transaction.resolvedCurrency)
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
        /// Transaction currency whose rate replaced the base rate (via a per-currency
        /// rule or the blanket foreign rate), or `nil` when the base rate applied.
        let currencyCode: String?
        /// The currency-based rate that replaced `baseRate`; `0` when none applied.
        let currencyRate: Decimal
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
        let currency = transaction.resolvedCurrency
        let currencyOverride = currencyOverrideRate(card: card, currency: currency)
        let effective = (currencyOverride ?? card.baseRewardRate) + (bonus?.rate ?? 0)
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
            currencyCode: currencyOverride != nil ? currency : nil,
            currencyRate: currencyOverride ?? 0,
            rewardType: card.rewardType,
            reward: reward
        )
    }

    // MARK: - Helpers

    private static func effectiveRate(card: Card, category: String?, currency: String? = nil) -> Decimal {
        let base = currencyOverrideRate(card: card, currency: currency) ?? card.baseRewardRate
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let rule = card.rewardRules.first(where: { $0.categoryName.caseInsensitiveCompare(raw) == .orderedSame }) {
            return base + rule.rate
        }
        return base
    }

    /// The currency-based rate that replaces the card's base rate for `currency`,
    /// or `nil` when the base rate applies. A per-currency rule wins over the
    /// blanket foreign rate, which applies to any non-default currency when set.
    private static func currencyOverrideRate(card: Card, currency: String?) -> Decimal? {
        guard let code = currency?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else { return nil }
        if let rule = card.currencyRules.first(where: { $0.currencyCode.caseInsensitiveCompare(code) == .orderedSame }) {
            return rule.rate
        }
        if card.foreignRewardRate > 0,
           code.caseInsensitiveCompare(CurrencyUtils.defaultCurrencyCode) != .orderedSame {
            return card.foreignRewardRate
        }
        return nil
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
