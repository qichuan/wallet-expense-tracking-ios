//
//  MascotCopy.swift
//  CardPulse
//

import Foundation

/// Pure copywriting for the mascot's speech bubbles. Picks a mood and a line
/// from the user's cycle state, so the views stay free of string logic.
enum MascotCopy {

    /// One goal card's state for the current cycle.
    struct Goal: Equatable {
        let name: String
        let remaining: Decimal
        let daysRemaining: Int
        let status: CardStatus
    }

    /// A bubble line. `emphasis`, when present, is rendered bold and colored before `text`.
    struct Line: Equatable {
        let mood: Mascot.Mood
        let emphasis: String?
        let text: String
    }

    /// Card that most needs attention: the behind card with the most left to spend,
    /// otherwise the unfinished card with the most left.
    static func focus(_ goals: [Goal]) -> Goal? {
        let open = goals.filter { $0.status != .hit }
        let behind = open.filter { $0.status == .behind }
        return (behind.isEmpty ? open : behind).max { $0.remaining < $1.remaining }
    }

    static func daysLeftText(_ days: Int) -> String {
        switch days {
        case 0:  return "Statement day today"
        case 1:  return "1 day left"
        default: return "\(days) days left"
        }
    }

    /// Per-day amount needed to finish, spreading over at least one day.
    static func perDay(_ goal: Goal) -> Decimal {
        goal.remaining / Decimal(max(1, goal.daysRemaining))
    }

    // MARK: - Today

    static func today(goals: [Goal], money: (Decimal) -> String) -> Line {
        guard !goals.isEmpty else {
            return Line(mood: .happy, emphasis: nil,
                        text: "Tap to pay and I'll log it for you. Give a card a min-spend target and I'll cheer you on!")
        }
        guard let goal = focus(goals) else {
            return Line(mood: .excited, emphasis: nil, text: "Every card has hit its target. Shiok!")
        }
        let days = daysLeftText(goal.daysRemaining)
        let ask = "\(goal.name) still needs \(money(goal.remaining)), about \(money(perDay(goal))) a day."
        if goal.status == .behind {
            return Line(mood: .worried, emphasis: goal.daysRemaining > 1 ? "Only \(days)" : days,
                        text: " this cycle! \(ask) Jia you!")
        }
        return Line(mood: .happy, emphasis: days, text: " this cycle. \(ask) Steady lah!")
    }

    // MARK: - Cards

    static func cards(goals: [Goal], money: (Decimal) -> String) -> Line {
        guard !goals.isEmpty else {
            return Line(mood: .normal, emphasis: nil,
                        text: "No targets yet. Set a min-spend goal on a card and I'll keep watch.")
        }
        guard let goal = focus(goals) else {
            return Line(mood: .excited, emphasis: nil, text: "Every card has smashed its target. Rewards unlocked!")
        }
        let days = daysLeftText(goal.daysRemaining)
        if goal.status == .behind {
            return Line(mood: .worried, emphasis: nil,
                        text: "\(days)! \(goal.name) still needs \(money(goal.remaining)). I'm sweating a bit…")
        }
        return Line(mood: .happy, emphasis: nil, text: "\(days) and every card is on track. Shiok!")
    }

    // MARK: - Recap

    /// - Parameters:
    ///   - current: spend in the selected period.
    ///   - previous: spend in the period before it; `nil` or 0 when there's nothing to compare.
    ///   - previousLabel: e.g. "last week", "September".
    static func recap(current: Decimal, previous: Decimal?, previousLabel: String) -> Line {
        guard current > 0 || (previous ?? 0) > 0 else {
            return Line(mood: .normal, emphasis: nil, text: "Nothing spent here yet. Your wallet says thank you!")
        }
        guard let previous, previous > 0 else {
            return Line(mood: .happy, emphasis: nil, text: "Here's where your money went. Tap a bar to dig in!")
        }
        let change = (current - previous) / previous * 100
        let percent = NSDecimalNumber(decimal: change).doubleValue
        let rounded = Int(abs(percent).rounded())
        if rounded == 0 {
            return Line(mood: .happy, emphasis: nil, text: "Same as \(previousLabel). Very consistent, I like it!")
        }
        if percent < 0 {
            return Line(mood: .excited, emphasis: nil,
                        text: "You spent \(rounded)% less than \(previousLabel). Wah, power! Keep this up and I might cry happy tears.")
        }
        return Line(mood: .worried, emphasis: nil,
                    text: "\(rounded)% more than \(previousLabel). No judgement, but maybe go easy ah?")
    }
}
