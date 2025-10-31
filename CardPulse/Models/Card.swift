//
//  Card.swift
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
    var minimumSpendingAmount: Decimal
    var hasMinimumSpending: Bool
    var rewardType: String
    var createdAt: Date
    var minimumSpendingByDayOfMonth: Int // 1...31
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.card)
    var transactions: [Transaction] = []
    
    init(name: String, minimumSpendingAmount: Decimal, hasMinimumSpending: Bool = false, rewardType: String, minimumSpendingByDayOfMonth: Int = 1) {
        self.id = UUID()
        self.name = name
        self.minimumSpendingAmount = minimumSpendingAmount
        self.hasMinimumSpending = hasMinimumSpending
        self.rewardType = rewardType
        self.createdAt = Date()
        self.minimumSpendingByDayOfMonth = max(1, min(31, minimumSpendingByDayOfMonth))
    }
    
    var progressPercentage: Double {
        guard minimumSpendingAmount > 0 else { return 0 }
        let spentThisCycle = Double(truncating: monthlySpent as NSDecimalNumber)
        let percentage = spentThisCycle / Double(truncating: minimumSpendingAmount as NSDecimalNumber)
        return max(0, min(1, percentage))
    }
    
    var remainingAmount: Decimal {
        return max(0, minimumSpendingAmount - monthlySpent)
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
        let day = min(minimumSpendingByDayOfMonth, calendar.range(of: .day, in: .month, for: now)?.count ?? minimumSpendingByDayOfMonth)
        comps.day = day
        let thisMonthStatement = calendar.date(from: comps) ?? now
        if now >= thisMonthStatement {
            return thisMonthStatement
        } else {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            var prevComps = calendar.dateComponents([.year, .month], from: prevMonth)
            let prevDay = min(minimumSpendingByDayOfMonth, calendar.range(of: .day, in: .month, for: prevMonth)?.count ?? minimumSpendingByDayOfMonth)
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


