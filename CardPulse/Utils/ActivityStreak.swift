//
//  ActivityStreak.swift
//  CardPulse
//

import Foundation

/// Pure day-streak math behind the Today streak pill, week flame strip and the Me
/// tab's calendar. A day is "active" when at least one transaction was logged on it.
/// Nothing is persisted: everything is derived from transaction dates.
struct ActivityStreak {

    enum DayState: Equatable {
        /// At least one transaction that day.
        case done
        /// Today, nothing logged yet (streak not broken until tomorrow).
        case pendingToday
        /// A past day with nothing logged.
        case missed
        /// After today.
        case future
    }

    struct WeekDay: Identifiable, Equatable {
        let date: Date
        /// Single-letter weekday label ("M", "T", …).
        let label: String
        let state: DayState
        let isToday: Bool

        var id: Date { date }
    }

    let calendar: Calendar
    let now: Date
    /// Start-of-day of every active day.
    let activeDays: Set<Date>

    init(dates: [Date], now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        self.now = now
        self.activeDays = Set(dates.map { calendar.startOfDay(for: $0) })
    }

    private var today: Date { calendar.startOfDay(for: now) }

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }

    /// Consecutive active days ending today, or ending yesterday when nothing has
    /// been logged today yet. 0 when yesterday and today are both inactive.
    var currentStreak: Int {
        var cursor = activeDays.contains(today) ? today : day(-1, from: today)
        var count = 0
        while activeDays.contains(cursor) {
            count += 1
            cursor = day(-1, from: cursor)
        }
        return count
    }

    /// Longest run of consecutive active days ever.
    var bestStreak: Int {
        var best = 0
        for start in activeDays where !activeDays.contains(day(-1, from: start)) {
            var length = 1
            var cursor = day(1, from: start)
            while activeDays.contains(cursor) {
                length += 1
                cursor = day(1, from: cursor)
            }
            best = max(best, length)
        }
        return best
    }

    /// Day-of-month numbers that were active in the month containing `date`.
    func activeDays(inMonthOf date: Date) -> Set<Int> {
        let month = calendar.dateComponents([.year, .month], from: date)
        return Set(activeDays.compactMap { d -> Int? in
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            return c.year == month.year && c.month == month.month ? c.day : nil
        })
    }

    /// Monday-to-Sunday entries for the week containing `now`.
    var weekStrip: [WeekDay] {
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        let monday = day(-((weekday + 5) % 7), from: today)
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { i in
            let date = day(i, from: monday)
            let state: DayState
            if date > today {
                state = .future
            } else if activeDays.contains(date) {
                state = .done
            } else {
                state = date == today ? .pendingToday : .missed
            }
            return WeekDay(date: date, label: labels[i], state: state, isToday: date == today)
        }
    }
}
