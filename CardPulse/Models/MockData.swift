//
//  MockData.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

extension ModelContainer {
    static func createMockContainer() -> ModelContainer {
        let schema = Schema([Card.self, Transaction.self, SpendingCategory.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Add mock data
            let mockCards = createMockCards()
            let mockTransactions = createMockTransactions(for: mockCards)
            let mockRules = sampleRules(for: mockCards)

            for card in mockCards {
                container.mainContext.insert(card)
            }

            for transaction in mockTransactions {
                container.mainContext.insert(transaction)
            }

            for rule in mockRules {
                container.mainContext.insert(rule)
            }

            try CategorySeeding.seedBuiltInsIfNeeded(in: container.mainContext)
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private static func createMockCards() -> [Card] {
        return [
            Card(
                name: "Apple Card",
                minimumSpendingAmount: 1000,
                hasMinimumSpending: true,
                rewardType: .cashback,
                baseRewardRate: 1.6,
                roundingBlock: 1
            ),
            Card(
                name: "Chase Sapphire Preferred",
                minimumSpendingAmount: 1500,
                hasMinimumSpending: true,
                rewardType: .miles,
                baseRewardRate: 1.4,
                roundingBlock: 5
            ),
            Card(
                name: "Amex Gold Card",
                minimumSpendingAmount: 2000,
                hasMinimumSpending: true,
                rewardType: .miles,
                baseRewardRate: 2.0,
                roundingBlock: 1
            ),
            Card(
                name: "Citi Double Cash",
                minimumSpendingAmount: 2000,
                hasMinimumSpending: true,
                rewardType: .cashback,
                baseRewardRate: 2.0,
                roundingBlock: 1
            )
        ]
    }

    private static func sampleRules(for cards: [Card]) -> [CardRewardRule] {
        var rules: [CardRewardRule] = []
        if let first = cards.first(where: { $0.rewardType == .cashback }) {
            rules.append(CardRewardRule(card: first, categoryName: "Food & Drinks", rate: 4))
            rules.append(CardRewardRule(card: first, categoryName: "Travel", rate: 3))
        }
        if let miles = cards.first(where: { $0.rewardType == .miles }) {
            rules.append(CardRewardRule(card: miles, categoryName: "Travel", rate: 4))
        }
        return rules
    }
    
    private static func createMockTransactions(for cards: [Card]) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        let merchants = [
            ("Apple Store", "Shopping", "New iPhone case"),
            ("Starbucks", "Dining Out", "Morning coffee"),
            ("DoorDash", "Dining Out", "Lunch delivery"),
            ("Whole Foods Market", "Groceries", "Weekly groceries"),
            ("Uber", "Transport", "Airport ride"),
            ("Netflix", "Entertainment", "Monthly subscription"),
            ("Shell", "Transport", "Gas fill-up"),
            ("Target", "Shopping", "Household items"),
            ("McDonald's", "Dining Out", "Quick dinner"),
            ("Amazon", "Shopping", "Online order")
        ]
        
        var transactions: [Transaction] = []
        
        for card in cards {
            for i in 0..<10 {
                let merchant = merchants[i % merchants.count]
                let amount = Decimal(Double.random(in: 5...200))
                let daysAgo = Int.random(in: 0...30)
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                
                let transaction = Transaction(
                    merchant: merchant.0,
                    amount: amount,
                    date: date,
                    category: merchant.1,
                    note: merchant.2,
                    card: card
                )
                
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
}
