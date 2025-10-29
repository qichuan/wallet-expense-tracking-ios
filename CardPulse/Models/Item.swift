//
//  Models.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var name: String
    var totalGoal: Decimal
    var goalDeadline: Date
    var rewardType: String
    var currentSpent: Decimal
    var createdAt: Date
    var statementDay: Int // 1...31
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.card)
    var transactions: [Transaction] = []
    
    init(name: String, totalGoal: Decimal, goalDeadline: Date, rewardType: String, currentSpent: Decimal = 0, statementDay: Int = 1) {
        self.id = UUID()
        self.name = name
        self.totalGoal = totalGoal
        self.goalDeadline = goalDeadline
        self.rewardType = rewardType
        self.currentSpent = currentSpent
        self.createdAt = Date()
        self.statementDay = max(1, min(31, statementDay))
    }
    
    var progressPercentage: Double {
        guard totalGoal > 0 else { return 0 }
        let spentThisCycle = Double(truncating: monthlySpent as NSDecimalNumber)
        let percentage = spentThisCycle / Double(truncating: totalGoal as NSDecimalNumber)
        return max(0, min(1, percentage))
    }
    
    var remainingAmount: Decimal {
        return max(0, totalGoal - monthlySpent)
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: currentCycleEnd).day ?? 0
        return max(0, days)
    }

    // MARK: - Monthly/Cycle helpers
    var currentCycleStart: Date {
        let calendar = Calendar.current
        let now = Date()
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        let day = min(statementDay, calendar.range(of: .day, in: .month, for: now)?.count ?? statementDay)
        comps.day = day
        let thisMonthStatement = calendar.date(from: comps) ?? now
        if now >= thisMonthStatement {
            return thisMonthStatement
        } else {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            var prevComps = calendar.dateComponents([.year, .month], from: prevMonth)
            let prevDay = min(statementDay, calendar.range(of: .day, in: .month, for: prevMonth)?.count ?? statementDay)
            prevComps.day = prevDay
            return calendar.date(from: prevComps) ?? now
        }
    }

    var currentCycleEnd: Date {
        let calendar = Calendar.current
        let start = currentCycleStart
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return next
    }

    var monthlySpent: Decimal {
        transactions.filter { $0.date >= currentCycleStart && $0.date < currentCycleEnd }
            .reduce(0) { $0 + $1.amount }
    }
}

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
