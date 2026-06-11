//
//  CardCurrencyRule.swift
//  CardPulse
//

import Foundation
import SwiftData

/// A per-currency override of a card's base reward rate.
///
/// `currencyCode` is an ISO 4217 code matching `Transaction.currency` storage.
/// Lookups are case-insensitive. Unlike `CardRewardRule` (additive category
/// bonuses), a currency rule *replaces* the base rate for transactions in that
/// currency — e.g. UOB PRVI Miles earns 1.2 mpd locally but 3 mpd in MYR.
@Model
final class CardCurrencyRule {
    var id: UUID
    var card: Card?
    var currencyCode: String
    /// Same units as `Card.baseRewardRate` (percent for cashback, miles per dollar for miles).
    var rate: Decimal
    var createdAt: Date

    init(card: Card? = nil, currencyCode: String, rate: Decimal) {
        self.id = UUID()
        self.card = card
        self.currencyCode = currencyCode
        self.rate = rate
        self.createdAt = Date()
    }
}
