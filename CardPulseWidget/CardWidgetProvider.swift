//
//  CardWidgetProvider.swift
//  CardPulseWidget
//

import WidgetKit
import SwiftUI

struct CardWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> CardWidgetEntry {
        CardWidgetEntry(
            date: Date(),
            cards: [
                CardSpendData(
                    id: UUID(), name: "Chase Sapphire",
                    monthlySpent: 850, minimumSpending: 1500,
                    hasMinimumSpending: true, daysRemaining: 12,
                    rewardType: "miles", spendingPeriodDisplay: "Mar 1 – Mar 31"
                )
            ],
            lastUpdated: Date()
        )
    }

    func snapshot(for configuration: CardWidgetIntent, in context: Context) async -> CardWidgetEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: CardWidgetIntent, in context: Context) async -> Timeline<CardWidgetEntry> {
        let nextRefresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry(for: configuration)], policy: .after(nextRefresh))
    }

    // MARK: - Helpers

    private func entry(for configuration: CardWidgetIntent) -> CardWidgetEntry {
        let snapshot = WidgetDataWriter.read()
        let eligible = (snapshot?.cards ?? []).filter { $0.hasMinimumSpending && $0.minimumSpending > 0 }

        let cards: [CardSpendData]
        let selectedIDs = configuration.selectedCards?.map { $0.id } ?? []
        if selectedIDs.isEmpty {
            // Default: show up to 3 cards sorted by lowest progress (most urgent first)
            cards = Array(eligible.sorted { $0.progressPercentage < $1.progressPercentage }.prefix(3))
        } else {
            // Respect the user's chosen order, max 3
            cards = selectedIDs.prefix(3).compactMap { id in eligible.first { $0.id.uuidString == id } }
        }

        return CardWidgetEntry(date: Date(), cards: cards, lastUpdated: snapshot?.lastUpdated ?? Date())
    }
}
