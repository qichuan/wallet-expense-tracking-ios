//
//  CardUtils.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import Foundation
import SwiftData

extension Card {
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
        let now = Date()
        
        // Get statement date for current month
        let currentMonthStatement = statementDate(for: now, calendar: calendar)
        
        // If we're on or after the statement date this month, count days to next month's statement
        let targetStatement: Date
        if now >= currentMonthStatement {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            targetStatement = statementDate(for: nextMonth, calendar: calendar)
        } else {
            // We're before the statement date this month, count days to this month's statement
            targetStatement = currentMonthStatement
        }
        
        // Calculate days from now to the statement date (inclusive)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: targetStatement)).day ?? 0
        return max(0, days)
    }

    // MARK: - Monthly/Cycle helpers
    
    /// Gets the statement date for a given month, handling months with fewer days
    func statementDate(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        
        // If the statement day exceeds days in month, use the last day of the month
        let actualDay = min(minimumSpendingByDayOfMonth, daysInMonth)
        
        var comps = components
        comps.day = actualDay
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        
        return calendar.date(from: comps) ?? date
    }
    
    var currentCycleStart: Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get statement date for current month
        let currentMonthStatement = statementDate(for: now, calendar: calendar)
        
        // If we're on or after the statement date this month, we're in a new cycle
        // Cycle started: (this month's statement date) + 1 day
        if now >= currentMonthStatement {
            if let cycleStart = calendar.date(byAdding: .day, value: 1, to: currentMonthStatement) {
                return calendar.startOfDay(for: cycleStart)
            }
            return calendar.startOfDay(for: now)
        } else {
            // We're before the statement date this month, cycle started the day after previous statement
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let lastMonthStatement = statementDate(for: lastMonth, calendar: calendar)
            
            // Add 1 day to get the start of the cycle
            if let cycleStart = calendar.date(byAdding: .day, value: 1, to: lastMonthStatement) {
                return calendar.startOfDay(for: cycleStart)
            }
            return calendar.startOfDay(for: now)
        }
    }

    var currentCycleEnd: Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get statement date for current month
        let currentMonthStatement = statementDate(for: now, calendar: calendar)
        
        // If we're on or after the statement date this month, cycle ends at the start of the day after next month's statement
        if now >= currentMonthStatement {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let nextMonthStatement = statementDate(for: nextMonth, calendar: calendar)
            // Return the start of the day after the statement date (exclusive end for filtering)
            if let dayAfter = calendar.date(byAdding: .day, value: 1, to: nextMonthStatement) {
                return calendar.startOfDay(for: dayAfter)
            }
            return nextMonthStatement
        } else {
            // We're before the statement date this month, cycle ends at the start of the day after this month's statement
            if let dayAfter = calendar.date(byAdding: .day, value: 1, to: currentMonthStatement) {
                return calendar.startOfDay(for: dayAfter)
            }
            return currentMonthStatement
        }
    }

    var monthlySpent: Decimal {
        // Filter transactions within the cycle: >= start and < end (exclusive end)
        transactions.filter { $0.date >= currentCycleStart && $0.date < currentCycleEnd }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Returns a formatted string representing the current spending period
    var spendingPeriodDisplay: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let start = currentCycleStart
        // The actual end date for display is the day before currentCycleEnd (since currentCycleEnd is exclusive)
        let endDate = calendar.date(byAdding: .day, value: -1, to: currentCycleEnd) ?? currentCycleEnd
        
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: endDate)
        
        return "\(startStr) - \(endStr)"
    }
}

