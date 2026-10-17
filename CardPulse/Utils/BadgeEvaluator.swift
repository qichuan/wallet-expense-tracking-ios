//
//  BadgeEvaluator.swift
//  CardPulse
//

import Foundation

/// Pure rules for the Me tab's badges. Badges are derived from existing data
/// (streaks, transaction count, met billing cycles), never stored.
enum BadgeEvaluator {

    enum Kind: String, CaseIterable {
        case weekWarrior, targetSmasher, tidyTracker, monthMaster
    }

    struct Badge: Identifiable, Equatable {
        let kind: Kind
        let name: String
        let subtitle: String
        let symbol: String
        let unlocked: Bool

        var id: Kind { kind }
    }

    struct Inputs: Equatable {
        var bestStreak: Int
        var transactionCount: Int
        /// Completed cycles that met their minimum spend, plus cards that have
        /// already hit their target in the current cycle.
        var targetsHit: Int
    }

    static let weekStreakGoal = 7
    static let targetsGoal = 5
    static let transactionsGoal = 100
    static let monthStreakGoal = 30

    static func badges(for inputs: Inputs) -> [Badge] {
        [
            Badge(kind: .weekWarrior, name: "Week warrior", subtitle: "\(weekStreakGoal)-day streak",
                  symbol: "flame.fill", unlocked: inputs.bestStreak >= weekStreakGoal),
            Badge(kind: .targetSmasher, name: "Target smasher", subtitle: "\(targetsGoal) targets hit",
                  symbol: "trophy.fill", unlocked: inputs.targetsHit >= targetsGoal),
            Badge(kind: .tidyTracker, name: "Tidy tracker", subtitle: "\(transactionsGoal) taps logged",
                  symbol: "checkmark", unlocked: inputs.transactionCount >= transactionsGoal),
            Badge(kind: .monthMaster, name: "Month master",
                  subtitle: inputs.bestStreak >= monthStreakGoal
                    ? "\(monthStreakGoal)-day streak"
                    : "\(inputs.bestStreak) / \(monthStreakGoal) days",
                  symbol: "calendar", unlocked: inputs.bestStreak >= monthStreakGoal),
        ]
    }
}
