//
//  CycleNudgeScheduler.swift
//  CardPulse
//

import Foundation
import UserNotifications

/// Schedules proactive, money-saving local notifications from the existing cycle/cap
/// math (issue #46):
///
/// - **Min-spend reminder** — scheduled ahead of time with a calendar trigger a few days
///   before a card's statement, for cards that still need spend to hit their goal. It is
///   re-evaluated on every app foreground: rescheduled with the latest shortfall, or
///   cancelled once the goal is met. A fully-specified past date never fires, so a card
///   evaluated after its lead date simply gets no reminder that cycle (no double-fire).
/// - **Cap-reached** — fired once per cycle when a card's reward cap is hit, detected on
///   foreground. De-duplicated via a per-card "last fired cycle" ledger so it can fire
///   again in a later cycle but never twice in the same one.
///
/// Tapping either notification opens the relevant card (see `NotificationRouter`).
/// Nothing is scheduled unless notification permission is already authorized — this never
/// prompts (the onboarding / Home banner own the permission request).
@MainActor
enum CycleNudgeScheduler {

    /// Days before the statement date that the min-spend reminder fires.
    static let leadDays = 3

    private static let minSpendPrefix = "nudge.minspend."
    private static let capLedgerKey = "cycleNudge.capFiredCycle"

    static func evaluate(cards: [Card]) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        await cleanUpStaleMinSpendRequests(cards: cards, center: center)

        for card in cards {
            await evaluateMinSpend(card, center: center)
            await evaluateCap(card, center: center)
        }

        pruneCapLedger(to: cards)
    }

    // MARK: - Min-spend reminder

    private static func evaluateMinSpend(_ card: Card, center: UNUserNotificationCenter) async {
        let id = minSpendIdentifier(for: card)

        // Not a goal card, or the goal is already met → ensure no reminder is pending.
        guard card.hasMinimumSpending, card.minimumSpendingAmount > 0, card.remainingAmount > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }

        guard
            let statementDay = Calendar.current.date(byAdding: .day, value: -1, to: card.currentCycleEnd),
            let fireBase = Calendar.current.date(byAdding: .day, value: -leadDays, to: statementDay)
        else { return }

        var fireComponents = Calendar.current.dateComponents([.year, .month, .day], from: fireBase)
        fireComponents.hour = 10
        fireComponents.minute = 0

        // The reminder window for this cycle has already passed (the app wasn't opened
        // before the lead date) → don't add a request that can never fire.
        guard let fireDate = Calendar.current.date(from: fireComponents), fireDate > Date() else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }

        let symbol = CurrencyUtils.symbol(for: CurrencyUtils.defaultCurrencyCode)
        let remaining = String(format: "%.0f", Double(truncating: card.remainingAmount as NSDecimalNumber))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let content = UNMutableNotificationContent()
        content.title = "Min-spend reminder"
        content.body = "\(symbol)\(remaining) to go on \(card.name) before the statement on \(dateFormatter.string(from: statementDay))."
        content.sound = .default
        content.userInfo = [NotificationRouter.cardIdUserInfoKey: card.id.uuidString]

        // Full y/m/d/h/m components → fires once, only if that moment is still in the future.
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Removes leftover min-spend reminders from previous cycles (their identifier no
    /// longer matches any card's current cycle), so never-fired past-dated requests
    /// don't accumulate.
    private static func cleanUpStaleMinSpendRequests(cards: [Card], center: UNUserNotificationCenter) async {
        let validIds = Set(cards.map(minSpendIdentifier(for:)))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(minSpendPrefix) && !validIds.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    // MARK: - Cap reached

    private static func evaluateCap(_ card: Card, center: UNUserNotificationCenter) async {
        let status = RewardCalculator.cycleRewardStatus(for: card)
        guard status.isCapReached else { return }

        // Fire at most once per cycle per card.
        let cycle = cycleKey(for: card)
        var ledger = capLedger()
        guard ledger[card.id.uuidString] != cycle else { return }

        let unit = card.rewardType == .miles ? "miles" : "cashback"
        let content = UNMutableNotificationContent()
        content.title = "Reward cap reached"
        content.body = "You've hit \(card.name)'s \(unit) cap for this cycle — other cards may now earn more."
        content.sound = .default
        content.userInfo = [NotificationRouter.cardIdUserInfoKey: card.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: capIdentifier(for: card), content: content, trigger: trigger)
        do {
            try await center.add(request)
            ledger[card.id.uuidString] = cycle
            saveCapLedger(ledger)
            AnalyticsTracker.log(AnalyticsTracker.Event.nudgeCapFired)
        } catch {
            // Ignore scheduling failures silently.
        }
    }

    // MARK: - Identifiers & ledger

    private static func cycleKey(for card: Card) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: card.currentCycleStart)
    }

    private static func minSpendIdentifier(for card: Card) -> String {
        "\(minSpendPrefix)\(card.id.uuidString).\(cycleKey(for: card))"
    }

    private static func capIdentifier(for card: Card) -> String {
        "nudge.cap.\(card.id.uuidString).\(cycleKey(for: card))"
    }

    private static func capLedger() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: capLedgerKey) as? [String: String] ?? [:]
    }

    private static func saveCapLedger(_ ledger: [String: String]) {
        UserDefaults.standard.set(ledger, forKey: capLedgerKey)
    }

    /// Drops ledger entries for cards that no longer exist so it stays bounded.
    private static func pruneCapLedger(to cards: [Card]) {
        let liveIds = Set(cards.map { $0.id.uuidString })
        let ledger = capLedger()
        let pruned = ledger.filter { liveIds.contains($0.key) }
        if pruned.count != ledger.count {
            saveCapLedger(pruned)
        }
    }
}
