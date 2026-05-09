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
    var createdAt: Date

    init(card: Card? = nil, categoryName: String, rate: Decimal) {
        self.id = UUID()
        self.card = card
        self.categoryName = categoryName
        self.rate = rate
        self.createdAt = Date()
    }
}
