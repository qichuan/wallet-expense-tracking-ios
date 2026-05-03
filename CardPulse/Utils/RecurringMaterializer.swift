//
//  RecurringMaterializer.swift
//  CardPulse
//

import Foundation
import SwiftData

/// Materializes monthly recurring transactions on app launch.
///
/// A "series" is a `(merchant, card, currency)` group. The latest transaction
/// in a series is the live template — when its `isRecurring` flag is true,
/// new monthly instances are created up to today. Toggling the flag off on
/// the latest instance stops the chain.
///
/// The recurrence anchor day is the day-of-month of the *earliest* recurring
/// transaction in the series. When the target month doesn't contain that day
/// (e.g. anchor 31 in February), the materializer clamps to the month's last day.
/// This preserves "always the 31st" semantics across short months.
enum RecurringMaterializer {

    /// Group key — merchant comparison is case- and whitespace-insensitive so
    /// minor edits ("Netflix" vs "netflix ") don't fragment a series.
    private struct GroupKey: Hashable {
        let merchant: String
        let cardID: UUID?
        let currency: String
    }

    /// Scans the store and creates any missing monthly recurrences whose due
    /// date is on or before `now`. Saves the context if anything was inserted.
    static func materialize(in context: ModelContext, now: Date = Date()) {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        guard let all = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var groups: [GroupKey: [Transaction]] = [:]
        for txn in all {
            let key = GroupKey(
                merchant: txn.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                cardID: txn.card?.id,
                currency: txn.resolvedCurrency
            )
            groups[key, default: []].append(txn)
        }

        var didInsert = false
        for (_, txns) in groups {
            let sorted = txns.sorted { $0.date < $1.date }
            guard let latest = sorted.last, latest.isRecurring else { continue }
            guard let anchor = sorted.first(where: { $0.isRecurring }) else { continue }
            let anchorDay = calendar.component(.day, from: anchor.date)

            var cursor = latest.date
            while let next = nextOccurrence(after: cursor, anchorDay: anchorDay, calendar: calendar),
                  calendar.startOfDay(for: next) <= today {
                let copy = Transaction(
                    merchant: latest.merchant,
                    amount: latest.amount,
                    date: next,
                    category: latest.category,
                    note: latest.note,
                    card: latest.card,
                    currency: latest.currency,
                    isRecurring: true
                )
                context.insert(copy)
                cursor = next
                didInsert = true
            }
        }

        guard didInsert else { return }
        do {
            try context.save()
        } catch {
            print("RecurringMaterializer: save failed — \(error)")
        }
    }

    /// Computes the next monthly occurrence after `date` using `anchorDay` for
    /// day-of-month, clamping to the target month's last day when the anchor
    /// doesn't exist in that month. Time-of-day is preserved from `date`.
    private static func nextOccurrence(after date: Date, anchorDay: Int, calendar: Calendar) -> Date? {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
        let ym = calendar.dateComponents([.year, .month], from: nextMonth)
        let tod = calendar.dateComponents([.hour, .minute, .second], from: date)
        guard let year = ym.year, let month = ym.month else { return nil }

        var probe = DateComponents()
        probe.year = year
        probe.month = month
        probe.day = 1
        guard let firstOfMonth = calendar.date(from: probe),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        let maxDay = range.upperBound - 1

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = min(anchorDay, maxDay)
        comps.hour = tod.hour
        comps.minute = tod.minute
        comps.second = tod.second
        return calendar.date(from: comps)
    }
}
