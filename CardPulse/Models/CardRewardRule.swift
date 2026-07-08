//
//  CardRewardRule.swift
//  CardPulse
//

import Foundation
import SwiftData

/// A per-category override of a card's base reward rate.
///
/// `categoryName` is a loose foreign key by name to a `SpendingCategory.name` —
/// matching `Transaction.category` storage. Lookups are case-insensitive.
@Model
final class CardRewardRule {
    var id: UUID
    var card: Card?
    var categoryName: String
    /// Same units as `Card.baseRewardRate` (percent for cashback, miles per dollar for miles).
    var rate: Decimal
    /// Maximum reward earnable in this category per **calendar month**. `0` means no cap.
    /// Units match the reward type: miles for a miles card, cashback (in the default
    /// currency) for a cashback card. Distinct from the card-wide `maxMilesCap` /
    /// `maxCashbackCap`, which are billing-cycle caps applied on top of this one.
    var maxRewardCap: Decimal = 0
    var createdAt: Date

    init(card: Card? = nil, categoryName: String, rate: Decimal, maxRewardCap: Decimal = 0) {
        self.id = UUID()
        self.card = card
        self.categoryName = categoryName
        self.rate = rate
        self.maxRewardCap = maxRewardCap
        self.createdAt = Date()
    }
}
