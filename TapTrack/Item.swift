//
//  Models.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var name: String
    var bank: String
    var last4: String
    var totalGoal: Decimal
    var goalDeadline: Date
    var rewardType: String
    var currentSpent: Decimal
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.card)
    var transactions: [Transaction] = []
    
    init(name: String, bank: String, last4: String, totalGoal: Decimal, goalDeadline: Date, rewardType: String, currentSpent: Decimal = 0) {
        self.id = UUID()
        self.name = name
        self.bank = bank
        self.last4 = last4
        self.totalGoal = totalGoal
        self.goalDeadline = goalDeadline
        self.rewardType = rewardType
        self.currentSpent = currentSpent
        self.createdAt = Date()
    }
    
    var progressPercentage: Double {
        guard totalGoal > 0 else { return 0 }
        return Double(truncating: currentSpent as NSDecimalNumber) / Double(truncating: totalGoal as NSDecimalNumber)
    }
    
    var remainingAmount: Decimal {
        return max(0, totalGoal - currentSpent)
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: goalDeadline).day ?? 0
        return max(0, days)
    }
}

@Model
final class Transaction {
    var id: UUID
    var merchant: String
    var amount: Decimal
    var date: Date
    var category: String?
    var card: Card?
    
    init(merchant: String, amount: Decimal, date: Date, category: String? = nil, card: Card? = nil) {
        self.id = UUID()
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
        self.card = card
    }
}
