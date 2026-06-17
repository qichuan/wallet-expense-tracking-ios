//
//  CycleNudgeSchedulerTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

/// Covers the pure decision logic behind cycle nudges (issue #46): lead-time clamping,
/// the reminder fire-date math, and cap once-per-cycle de-duplication. The scheduling
/// side-effects against `UNUserNotificationCenter` are integration-only and not covered
/// here.
@MainActor
final class CycleNudgeSchedulerTests: XCTestCase {

    // MARK: - Lead-days resolution

    func testResolvedLeadDays_UnsetReturnsDefault() {
        // UserDefaults.integer returns 0 when unset.
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: 0), CycleNudgeScheduler.defaultLeadDays)
    }

    func testResolvedLeadDays_InRangeKept() {
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: 1), 1)
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: 5), 5)
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: 30), 30)
    }

    func testResolvedLeadDays_OutOfRangeFallsBackToDefault() {
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: -3), CycleNudgeScheduler.defaultLeadDays)
        XCTAssertEqual(CycleNudgeScheduler.resolvedLeadDays(stored: 31), CycleNudgeScheduler.defaultLeadDays)
    }

    // MARK: - Reminder fire date

    func testReminderFireComponents_IsLeadDaysBeforeStatementAtTen() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!

        // Statement on 15 Jun 2026, 3 days lead → fire 12 Jun 2026 at 10:00.
        let statement = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23, minute: 59))!
        let components = try XCTUnwrap(
            CycleNudgeScheduler.reminderFireComponents(statementDate: statement, leadDays: 3, calendar: calendar)
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 12)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
    }

    func testReminderFireComponents_CrossesMonthBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!

        // Statement on 2 Jul, 3 days lead → 29 Jun.
        let statement = calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 23, minute: 59))!
        let components = try XCTUnwrap(
            CycleNudgeScheduler.reminderFireComponents(statementDate: statement, leadDays: 3, calendar: calendar)
        )

        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 29)
        XCTAssertEqual(components.hour, 10)
    }

    func testReminderFireComponents_RespectsCustomLeadDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!

        let statement = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23, minute: 59))!
        let components = try XCTUnwrap(
            CycleNudgeScheduler.reminderFireComponents(statementDate: statement, leadDays: 7, calendar: calendar)
        )

        XCTAssertEqual(components.day, 8) // 15 - 7
        XCTAssertEqual(components.month, 6)
    }

    // MARK: - Cap dedup

    func testShouldFireCapNudge_FirstTimeThisCycle() {
        XCTAssertTrue(CycleNudgeScheduler.shouldFireCapNudge(lastFiredCycle: nil, currentCycle: "20260601"))
    }

    func testShouldFireCapNudge_AlreadyFiredThisCycle() {
        XCTAssertFalse(CycleNudgeScheduler.shouldFireCapNudge(lastFiredCycle: "20260601", currentCycle: "20260601"))
    }

    func testShouldFireCapNudge_NewCycleFiresAgain() {
        XCTAssertTrue(CycleNudgeScheduler.shouldFireCapNudge(lastFiredCycle: "20260601", currentCycle: "20260701"))
    }
}
