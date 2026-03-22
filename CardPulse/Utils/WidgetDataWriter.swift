//
//  WidgetDataWriter.swift
//  CardPulse
//

import Foundation
import WidgetKit

// Shared data model — compiled into both the app and the widget extension.
struct CardSpendData: Codable, Identifiable {
    let id: UUID
    let name: String
    let monthlySpent: Double
    let minimumSpending: Double
    let hasMinimumSpending: Bool
    let daysRemaining: Int
    let rewardType: String
    let spendingPeriodDisplay: String

    var progressPercentage: Double {
        guard minimumSpending > 0 else { return 0 }
        return min(1.0, monthlySpent / minimumSpending)
    }
}

struct WidgetSnapshot: Codable {
    let cards: [CardSpendData]
    let lastUpdated: Date
}

enum WidgetDataWriter {
    static let appGroupID = "group.com.zqc.TapTrack"
    private static let defaultsKey = "widget_snapshot"

    /// Called from the main app after any SwiftData save.
    static func write(spendData: [CardSpendData]) {
        let snapshot = WidgetSnapshot(cards: spendData, lastUpdated: Date())
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(encoded, forKey: defaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Called from the widget extension's TimelineProvider.
    static func read() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
