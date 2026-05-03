//
//  RecurringMaterializer.swift
//  CardPulse
//

import Foundation
import SwiftData

/// Materializes monthly recurring transactions.
///
/// A "series" is a `(merchant, card, currency)` group. The chain marker is a
/// single `isRecurring = true` flag carried by the **most recent** member of
/// the series — every older member must have `isRecurring = false`. Toggling
/// the flag off on the latest instance stops the chain.
///
/// `materialize` is invoked at app launch and after the user saves a
/// transaction with `isRecurring = true`. It performs two passes per series:
///
/// 1. **Backfill.** Walks monthly anchor dates from the most recent recurring
///    transaction up to today and inserts a copy for every missing month —
///    so toggling `isRecurring` on a past transaction (say 1 Jan) immediately
///    creates 1 Feb, 1 Mar, 1 Apr, 1 May entries.
/// 2. **Normalize.** Sets `isRecurring = true` on the (post-backfill) most
///    recent member and clears the flag on every other member of the series.
///
/// The recurrence anchor day is the day-of-month of the most recent recurring
/// transaction. When the target month doesn't contain that day (e.g. anchor 31
/// in February), the materializer clamps to the month's last day, preserving
/// "always the 31st" semantics across short months.
enum RecurringMaterializer {

    /// Group key — merchant comparison is case- and whitespace-insensitive so
    /// minor edits ("Netflix" vs "netflix ") don't fragment a series.
    private struct GroupKey: Hashable {
        let merchant: String
        let cardID: UUID?
        let currency: String
    }

    /// Backfills missing monthly recurrences and enforces the
    /// "only-latest-is-recurring" invariant across every series. Saves the
    /// context if anything changed.
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

        var didChange = false
        for (_, txns) in groups {
            var members = txns.sorted { $0.date < $1.date }

            // Anchor / template: the most recent recurring transaction in the
            // series. On a normal launch this is the chain marker carried
            // forward from the prior run; right after the user toggles a past
            // transaction it's the seed they just saved.
            guard let anchor = members.last(where: { $0.isRecurring }) else { continue }
            let anchorDay = calendar.component(.day, from: anchor.date)

            // Backfill: walk forward from the anchor, inserting a copy for
            // every missing monthly slot up to today. The exists-check guards
            // against creating a duplicate when an unrelated transaction
            // already lives on that calendar day.
            var cursor = anchor.date
            while let next = nextOccurrence(after: cursor, anchorDay: anchorDay, calendar: calendar),
                  calendar.startOfDay(for: next) <= today {
                cursor = next
                let alreadyExists = members.contains { calendar.isDate($0.date, inSameDayAs: next) }
                if !alreadyExists {
                    let copy = Transaction(
                        merchant: anchor.merchant,
                        amount: anchor.amount,
                        date: next,
                        category: anchor.category,
                        note: anchor.note,
                        card: anchor.card,
                        currency: anchor.currency,
                        isRecurring: false
                    )
                    context.insert(copy)
                    members.append(copy)
                    didChange = true
                }
            }

            // Normalize: only the most recent member keeps the flag.
            members.sort { $0.date < $1.date }
            guard let newLatest = members.last else { continue }
            for txn in members where txn !== newLatest && txn.isRecurring {
                txn.isRecurring = false
                didChange = true
            }
            if !newLatest.isRecurring {
                newLatest.isRecurring = true
                didChange = true
            }
        }

        guard didChange else { return }
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
