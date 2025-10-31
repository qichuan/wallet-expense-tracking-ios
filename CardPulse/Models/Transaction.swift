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
    var date: Date
    var category: String?
    var note: String?
    var card: Card?
    
    init(merchant: String, amount: Decimal, date: Date, category: String? = nil, note: String? = nil, card: Card? = nil) {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
        self.note = note
        self.card = card
    }
}


