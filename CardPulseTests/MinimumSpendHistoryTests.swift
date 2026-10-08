//
//  MinimumSpendHistoryTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

/// Covers the billing-cycle bucketing behind the card detail's minimum-spend badge grid (issue #69).
final class MinimumSpendHistoryTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func cycles(
        statementDay: Int = 15,
        minimum: Decimal = 500,
        spends: [(date: Date, amount: Decimal)],
        now: Date,
        limit: Int = MinimumSpendHistory.defaultLimit
    ) -> [MinimumSpendHistory.Cycle] {
        MinimumSpendHistory.pastCycles(
            statementDay: statementDay, minimum: minimum, spends: spends,
            now: now, calendar: calendar, limit: limit
        )
    }

    // MARK: - Boundaries

    func testExcludesInProgressCycleAndUsesStatementDayBoundaries() {
        // Statement day 15, today 20 Sep → in-progress cycle is 16 Sep–15 Oct.
        // Most recent completed cycle is 16 Aug–15 Sep.
        let result = cycles(spends: [(date(2026, 8, 20), 100)], now: date(2026, 9, 20))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].start, date(2026, 8, 16, 0))
        XCTAssertEqual(result[0].end, date(2026, 9, 16, 0))
    }

    func testOnStatementDayTheClosingCycleIsStillInProgress() {
        // 15 Sep at noon: the cycle ending 15 Sep 23:59:59 hasn't closed yet.
        let result = cycles(spends: [(date(2026, 7, 20), 100)], now: date(2026, 9, 15))

        XCTAssertEqual(result.first?.end, date(2026, 8, 16, 0))
    }

    func testStatementDay31ClampsToShortMonths() {
        // Statement day 31 → Feb cycle closes on 28 Feb, Mar cycle runs 1 Mar–31 Mar.
        let result = cycles(statementDay: 31, spends: [(date(2026, 2, 10), 100)], now: date(2026, 4, 10))

        XCTAssertEqual(result.map(\.start), [date(2026, 3, 1, 0), date(2026, 2, 1, 0)])
        XCTAssertEqual(result.map(\.end), [date(2026, 4, 1, 0), date(2026, 3, 1, 0)])
    }

    func testCycleSpanningYearBoundary() {
        let result = cycles(spends: [(date(2025, 12, 28), 600)], now: date(2026, 1, 20))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].start, date(2025, 12, 16, 0))
        XCTAssertEqual(result[0].end, date(2026, 1, 16, 0))
        XCTAssertEqual(result[0].outcome, .met)
    }

    // MARK: - Outcomes

    func testOutcomesMetMissedAndNoSpend() {
        let spends: [(date: Date, amount: Decimal)] = [
            (date(2026, 6, 20), 300), (date(2026, 7, 1), 200),   // 16 Jun–15 Jul: exactly 500 → met
            (date(2026, 7, 20), 499),                            // 16 Jul–15 Aug: missed
                                                                 // 16 Aug–15 Sep: no spend
        ]
        let result = cycles(spends: spends, now: date(2026, 9, 20))

        XCTAssertEqual(result.map(\.outcome), [.noSpend, .missed, .met])
        XCTAssertEqual(result.map(\.spent), [0, 499, 500])
    }

    // MARK: - Cutoffs

    func testDropsCyclesBeforeFirstSpend() {
        let result = cycles(spends: [(date(2026, 7, 20), 100)], now: date(2026, 9, 20))

        // Only the cycle containing the first spend and later ones.
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.last?.start, date(2026, 7, 16, 0))
    }

    func testNoSpendReturnsEmpty() {
        XCTAssertTrue(cycles(spends: [], now: date(2026, 9, 20)).isEmpty)
    }

    func testZeroMinimumReturnsEmpty() {
        XCTAssertTrue(cycles(minimum: 0, spends: [(date(2026, 7, 20), 100)], now: date(2026, 9, 20)).isEmpty)
    }

    func testLimitCapsCountNewestFirst() {
        let result = cycles(spends: [(date(2024, 1, 20), 100)], now: date(2026, 9, 20), limit: 12)

        XCTAssertEqual(result.count, 12)
        XCTAssertEqual(result.first?.end, date(2026, 9, 16, 0))
        XCTAssertEqual(result.last?.start, date(2025, 9, 16, 0))
    }
}
