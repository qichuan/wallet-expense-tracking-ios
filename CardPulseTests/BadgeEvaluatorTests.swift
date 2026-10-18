//
//  BadgeEvaluatorTests.swift
//  CardPulseTests
//

import XCTest
@testable import CardPulse

final class BadgeEvaluatorTests: XCTestCase {

    private func unlocked(_ inputs: BadgeEvaluator.Inputs) -> Set<BadgeEvaluator.Kind> {
        Set(BadgeEvaluator.badges(for: inputs).filter(\.unlocked).map(\.kind))
    }

    func testNothingUnlockedForNewUser() {
        XCTAssertEqual(unlocked(.init(bestStreak: 0, transactionCount: 0, targetsHit: 0)), [])
    }

    func testThresholdsAreInclusive() {
        XCTAssertEqual(unlocked(.init(bestStreak: 7, transactionCount: 100, targetsHit: 5)),
                       [.weekWarrior, .tidyTracker, .targetSmasher])
        XCTAssertEqual(unlocked(.init(bestStreak: 6, transactionCount: 99, targetsHit: 4)), [])
    }

    func testMonthMasterShowsProgressUntilUnlocked() {
        let locked = BadgeEvaluator.badges(for: .init(bestStreak: 13, transactionCount: 0, targetsHit: 0))
        XCTAssertEqual(locked.first { $0.kind == .monthMaster }?.subtitle, "13 / 30 days")

        let done = BadgeEvaluator.badges(for: .init(bestStreak: 30, transactionCount: 0, targetsHit: 0))
        let master = done.first { $0.kind == .monthMaster }
        XCTAssertEqual(master?.unlocked, true)
        XCTAssertEqual(master?.subtitle, "30-day streak")
    }

    func testBadgesKeepFixedOrder() {
        let kinds = BadgeEvaluator.badges(for: .init(bestStreak: 0, transactionCount: 0, targetsHit: 0)).map(\.kind)
        XCTAssertEqual(kinds, BadgeEvaluator.Kind.allCases)
    }
}
