//
//  MinimumSpendHistory.swift
//  CardPulse
//

import Foundation

/// Pure billing-cycle math behind the card detail's minimum-spend badge grid (issue #69).
/// Splits spend into completed billing cycles (statement day + 1 → next statement day)
/// and marks each one as met, missed, or without spend.
enum MinimumSpendHistory {

    static let defaultLimit = 12

    enum Outcome: Equatable {
        case met
        case missed
        case noSpend
    }

    struct Cycle: Identifiable, Equatable {
        /// Start of the cycle's first day (inclusive).
        let start: Date
        /// Start of the day after the statement date (exclusive), matching `Card.currentCycleEnd`.
        let end: Date
        /// The statement date that closes this cycle; used for the badge's month label.
        let statementDate: Date
        let spent: Decimal
        let outcome: Outcome

        var id: Date { start }
    }

    /// Statement date (23:59:59) for `statementDay` in the month containing `date`,
    /// clamped to the month's last day (e.g. day 31 → 28 Feb).
    static func statementDate(day statementDay: Int, for date: Date, calendar: Calendar) -> Date {
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = min(statementDay, daysInMonth)
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        return calendar.date(from: comps) ?? date
    }

    /// Completed billing cycles, newest first, up to `limit`. The in-progress cycle is excluded.
    /// Cycles that end before the earliest spend are dropped, so a new card doesn't
    /// show a run of "missed" badges; with no spend at all the result is empty.
    static func pastCycles(
        statementDay: Int,
        minimum: Decimal,
        spends: [(date: Date, amount: Decimal)],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = defaultLimit
    ) -> [Cycle] {
        guard minimum > 0, limit > 0, let earliest = spends.map(\.date).min() else { return [] }

        // First day of the month whose statement closed the most recent completed cycle.
        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        let closedThisMonth = now >= statementDate(day: statementDay, for: thisMonth, calendar: calendar)
        guard let anchorMonth = closedThisMonth
                ? thisMonth
                : calendar.date(byAdding: .month, value: -1, to: thisMonth) else { return [] }

        var cycles: [Cycle] = []
        for offset in 0..<limit {
            guard let endMonth = calendar.date(byAdding: .month, value: -offset, to: anchorMonth),
                  let startMonth = calendar.date(byAdding: .month, value: -1, to: endMonth) else { break }

            let closing = statementDate(day: statementDay, for: endMonth, calendar: calendar)
            let previous = statementDate(day: statementDay, for: startMonth, calendar: calendar)
            guard let start = calendar.date(byAdding: .day, value: 1, to: previous).map(calendar.startOfDay),
                  let end = calendar.date(byAdding: .day, value: 1, to: closing).map(calendar.startOfDay) else { break }

            // Cycles are walked newest → oldest, so everything from here on predates the first spend.
            if end <= earliest { break }

            let inCycle = spends.filter { $0.date >= start && $0.date < end }
            let spent = inCycle.reduce(Decimal(0)) { $0 + $1.amount }
            let outcome: Outcome
            if inCycle.isEmpty {
                outcome = .noSpend
            } else if spent >= minimum {
                outcome = .met
            } else {
                outcome = .missed
            }
            cycles.append(Cycle(start: start, end: end, statementDate: closing, spent: spent, outcome: outcome))
        }
        return cycles
    }
}

extension Card {
    /// Completed billing cycles judged against the card's minimum spend, newest first.
    /// Spend is converted to the default currency, as with `monthlySpent`.
    var minimumSpendHistory: [MinimumSpendHistory.Cycle] {
        guard hasMinimumSpending else { return [] }
        return MinimumSpendHistory.pastCycles(
            statementDay: effectiveStatementDay,
            minimum: minimumSpendingAmount,
            spends: transactions.map { (date: $0.date, amount: $0.amountInDefaultCurrency) }
        )
    }
}
