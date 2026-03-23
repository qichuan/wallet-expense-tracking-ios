//
//  WidgetDataWriter+App.swift
//  CardPulse
//
//  App-target only — uses SwiftData to fetch all cards and write a fresh snapshot.

import Foundation
import SwiftData

extension WidgetDataWriter {
    /// Fetches all cards from the given context and writes an updated widget snapshot.
    /// Call this after any modelContext.save() in the app.
    static func refresh(using context: ModelContext) {
        guard let cards = try? context.fetch(FetchDescriptor<Card>()) else { return }
        let spendData = cards.map { card in
            CardSpendData(
                id: card.id,
                name: card.name,
                monthlySpent: Double(truncating: card.monthlySpent as NSDecimalNumber),
                minimumSpending: Double(truncating: card.minimumSpendingAmount as NSDecimalNumber),
                hasMinimumSpending: card.hasMinimumSpending,
                daysRemaining: card.daysRemaining,
                rewardType: card.rewardType.rawValue,
                spendingPeriodDisplay: card.spendingPeriodDisplay
            )
        }
        write(spendData: spendData)
    }
}
