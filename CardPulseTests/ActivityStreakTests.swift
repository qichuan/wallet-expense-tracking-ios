//
//  ActivityStreakTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

/// Covers the derived day-streak math behind the Today streak pill, week strip and Me calendar.
final class ActivityStreakTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func streak(_ dates: [Date], now: Date) -> ActivityStreak {
        ActivityStreak(dates: dates, now: now, calendar: calendar)
    }

    // MARK: - Current streak

    func testCurrentStreakCountsBackFromToday() {
        let s = streak([date(2026, 10, 15), date(2026, 10, 16), date(2026, 10, 17, 9), date(2026, 10, 17, 20)],
                       now: date(2026, 10, 17, 22))
        XCTAssertEqual(s.currentStreak, 3)
    }

    func testCurrentStreakEndingYesterdayIsKeptUntilTodayEnds() {
        let s = streak([date(2026, 10, 15), date(2026, 10, 16)], now: date(2026, 10, 17))
        XCTAssertEqual(s.currentStreak, 2)
    }

    func testMissingDayBreaksStreak() {
        let s = streak([date(2026, 10, 13), date(2026, 10, 14), date(2026, 10, 16), date(2026, 10, 17)],
                       now: date(2026, 10, 17))
        XCTAssertEqual(s.currentStreak, 2)
    }

    func testNoActivityYesterdayOrTodayIsZero() {
        let s = streak([date(2026, 10, 14), date(2026, 10, 15)], now: date(2026, 10, 17))
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(streak([], now: date(2026, 10, 17)).currentStreak, 0)
    }

    func testStreakCrossesMonthBoundary() {
        let s = streak([date(2026, 9, 29), date(2026, 9, 30), date(2026, 10, 1)], now: date(2026, 10, 1))
        XCTAssertEqual(s.currentStreak, 3)
    }

    // MARK: - Best streak

    func testBestStreakFindsLongestRun() {
        let dates = [1, 2, 3, 4, 5, 8, 9, 15].map { date(2026, 10, $0) }
        let s = streak(dates, now: date(2026, 10, 17))
        XCTAssertEqual(s.bestStreak, 5)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(streak([], now: date(2026, 10, 17)).bestStreak, 0)
    }

    // MARK: - Calendar

    func testActiveDaysInMonthIgnoresOtherMonths() {
        let s = streak([date(2026, 9, 30), date(2026, 10, 3), date(2026, 10, 3, 18), date(2026, 10, 17), date(2025, 10, 5)],
                       now: date(2026, 10, 17))
        XCTAssertEqual(s.activeDays(inMonthOf: date(2026, 10, 1)), [3, 17])
    }

    // MARK: - Week strip

    func testWeekStripRunsMondayToSundayWithStates() {
        // Sat 17 Oct 2026 → week is Mon 12 – Sun 18.
        let s = streak([date(2026, 10, 12), date(2026, 10, 13), date(2026, 10, 16)], now: date(2026, 10, 17))
        let week = s.weekStrip
        XCTAssertEqual(week.map(\.label), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(week.first?.date, calendar.startOfDay(for: date(2026, 10, 12)))
        XCTAssertEqual(week.map(\.state), [.done, .done, .missed, .missed, .done, .pendingToday, .future])
        XCTAssertEqual(week.firstIndex(where: \.isToday), 5)
    }

    func testWeekStripOnSundayStartsPreviousMonday() {
        let s = streak([date(2026, 10, 18)], now: date(2026, 10, 18))
        XCTAssertEqual(s.weekStrip.first?.date, calendar.startOfDay(for: date(2026, 10, 12)))
        XCTAssertEqual(s.weekStrip.last?.state, .done)
    }
}
