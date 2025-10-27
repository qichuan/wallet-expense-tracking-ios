//
//  MockData.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData

extension ModelContainer {
    static func createMockContainer() -> ModelContainer {
        let schema = Schema([Card.self, Transaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Add mock data
            let mockCards = createMockCards()
            let mockTransactions = createMockTransactions(for: mockCards)
            
            for card in mockCards {
                container.mainContext.insert(card)
            }
            
            for transaction in mockTransactions {
                container.mainContext.insert(transaction)
            }
            
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private static func createMockCards() -> [Card] {
        let calendar = Calendar.current
        
        return [
            Card(
                name: "Apple Card",
                bank: "Apple",
                last4: "1234",
                totalGoal: 1000,
                goalDeadline: calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                rewardType: "cashback",
                currentSpent: 750
            ),
            Card(
                name: "Chase Sapphire Preferred",
                bank: "Chase",
                last4: "5678",
                totalGoal: 1500,
                goalDeadline: calendar.date(byAdding: .day, value: 45, to: Date()) ?? Date(),
                rewardType: "miles",
                currentSpent: 450
            ),
            Card(
                name: "Amex Gold Card",
                bank: "American Express",
                last4: "9012",
                totalGoal: 2000,
                goalDeadline: calendar.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
                rewardType: "points",
                currentSpent: 1950
            ),
            Card(
                name: "Citi Double Cash",
                bank: "Citi",
                last4: "3456",
                totalGoal: 2000,
                goalDeadline: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                rewardType: "miles",
                currentSpent: 1300
            )
        ]
    }
    
    private static func createMockTransactions(for cards: [Card]) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        let merchants = [
            ("Apple Store", "Shopping"),
            ("Starbucks", "Dining Out"),
            ("DoorDash", "Dining Out"),
            ("Whole Foods Market", "Groceries"),
            ("Uber", "Transport"),
            ("Netflix", "Entertainment"),
            ("Shell", "Transport"),
            ("Target", "Shopping"),
            ("McDonald's", "Dining Out"),
            ("Amazon", "Shopping")
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
                    card: card
                )
                
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
}
