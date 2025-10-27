//
//  TransactionManager.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData
import Combine

@MainActor
class TransactionManager: ObservableObject {
    private var modelContext: ModelContext
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func addTransaction(merchant: String, amount: Decimal, card: Card, category: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        let transaction = Transaction(
            merchant: merchant,
            amount: amount,
            date: Date(),
            category: category,
            card: card
        )
        
        modelContext.insert(transaction)
        
        // Update card's current spent amount
        card.currentSpent += amount
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error saving transaction: \(error.localizedDescription)"
            print("Error saving transaction: \(error)")
        }
        
        isLoading = false
    }
    
    func addCard(name: String, bank: String, last4: String, totalGoal: Decimal, goalDeadline: Date, rewardType: String) {
        isLoading = true
        errorMessage = nil
        
        let card = Card(
            name: name,
            bank: bank,
            last4: last4,
            totalGoal: totalGoal,
            goalDeadline: goalDeadline,
            rewardType: rewardType
        )
        
        modelContext.insert(card)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error saving card: \(error.localizedDescription)"
            print("Error saving card: \(error)")
        }
        
        isLoading = false
    }
    
    func updateCardGoal(card: Card, newGoal: Decimal, newDeadline: Date) {
        isLoading = true
        errorMessage = nil
        
        card.totalGoal = newGoal
        card.goalDeadline = newDeadline
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error updating card goal: \(error.localizedDescription)"
            print("Error updating card goal: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        isLoading = true
        errorMessage = nil
        
        if let card = transaction.card {
            card.currentSpent -= transaction.amount
        }
        
        modelContext.delete(transaction)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error deleting transaction: \(error.localizedDescription)"
            print("Error deleting transaction: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteCard(_ card: Card) {
        isLoading = true
        errorMessage = nil
        
        modelContext.delete(card)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error deleting card: \(error.localizedDescription)"
            print("Error deleting card: \(error)")
        }
        
        isLoading = false
    }
    
    func getTransactionsForCard(_ card: Card) -> [Transaction] {
        // Capture the UUID value to avoid optional key-path vs key-path comparison issues.
        let cardID = card.id
        let request = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.card?.id == cardID
            }
        )
        
        do {
            return try modelContext.fetch(request)
        } catch {
            print("Error fetching transactions: \(error)")
            return []
        }
    }
    
    func getTransactionsForPeriod(_ startDate: Date, _ endDate: Date) -> [Transaction] {
        let request = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= startDate && transaction.date <= endDate
            }
        )
        
        do {
            return try modelContext.fetch(request)
        } catch {
            print("Error fetching transactions for period: \(error)")
            return []
        }
    }
    
    func getSpendingByCategory(for transactions: [Transaction]) -> [String: Decimal] {
        var categorySpending: [String: Decimal] = [:]
        
        for transaction in transactions {
            let category = transaction.category ?? "Other"
            categorySpending[category, default: 0] += transaction.amount
        }
        
        return categorySpending
    }
    
    func exportToCSV() -> String {
        let request = FetchDescriptor<Transaction>()
        
        do {
            let transactions = try modelContext.fetch(request)
            var csvString = "Date,Merchant,Amount,Category,Card\n"
            
            for transaction in transactions {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                
                let dateString = dateFormatter.string(from: transaction.date)
                let merchant = transaction.merchant.replacingOccurrences(of: ",", with: ";")
                let amount = String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber))
                let category = transaction.category ?? "Other"
                let card = transaction.card?.name ?? "Unknown"
                
                csvString += "\(dateString),\(merchant),\(amount),\(category),\(card)\n"
            }
            
            return csvString
        } catch {
            print("Error exporting to CSV: \(error)")
            return ""
        }
    }
    
    func importFromCSV(_ csvString: String) {
        let lines = csvString.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue } // Skip header and empty lines
            
            let components = line.components(separatedBy: ",")
            guard components.count >= 4 else { continue }
            
            let dateString = components[0]
            let merchant = components[1]
            let amountString = components[2]
            let category = components.count > 3 ? components[3] : nil
            let cardName = components.count > 4 ? components[4] : nil
            
            guard let amount = Decimal(string: amountString) else { continue }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            var matchedCard: Card? = nil
            if let cardNameUnwrapped = cardName, !cardNameUnwrapped.isEmpty {
                // Find matching card by exact name
                let cardRequest = FetchDescriptor<Card>(
                    predicate: #Predicate { card in
                        card.name == cardNameUnwrapped
                    }
                )
                do {
                    matchedCard = try modelContext.fetch(cardRequest).first
                } catch {
                    print("Error fetching card for name \(cardNameUnwrapped): \(error)")
                }
            }
            
            let transaction = Transaction(
                merchant: merchant,
                amount: amount,
                date: date,
                category: category,
                card: matchedCard
            )
            
            modelContext.insert(transaction)
            
            if let matchedCard {
                matchedCard.currentSpent += amount
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving imported data: \(error)")
        }
    }
}
