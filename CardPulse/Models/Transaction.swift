//
//  Transaction.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var merchant: String
    var amount: Decimal
    /// Empty string means "use the default currency configured in Settings".
    var currency: String = ""
    var date: Date
    var category: String?
    var note: String?
    var card: Card?

    /// Resolved currency: falls back to the user's default when the stored value is empty.
    var resolvedCurrency: String {
        currency.isEmpty ? CurrencyUtils.defaultCurrencyCode : currency
    }

    init(merchant: String, amount: Decimal, date: Date, category: String? = nil, note: String? = nil, card: Card? = nil, currency: String = "") {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.note = note
        self.card = card
    }
}


