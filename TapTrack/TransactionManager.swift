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
    
    func addTransaction(merchant: String, amount: Decimal, card: Card, category: String? = nil, note: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        let transaction = Transaction(
            merchant: merchant,
            amount: amount,
            date: Date(),
            category: category,
            note: note,
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
    
    func exportToCSV(from startDate: Date? = nil, to endDate: Date? = nil) -> String {
        var request = FetchDescriptor<Transaction>()
        
        print("Exporting CSV from \(startDate?.description ?? "nil") to \(endDate?.description ?? "nil")")
        
        // First, check total transactions in database
        let totalRequest = FetchDescriptor<Transaction>()
        do {
            let totalTransactions = try modelContext.fetch(totalRequest)
            print("Total transactions in database: \(totalTransactions.count)")
        } catch {
            print("Error fetching total transactions: \(error)")
        }
        
        // Add date filtering if provided
        if let startDate = startDate, let endDate = endDate {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
            
            print("Date range: \(startOfDay) to \(endOfDay)")
            
            request.predicate = #Predicate { transaction in
                transaction.date >= startOfDay && transaction.date < endOfDay
            }
        }
        
        do {
            let transactions = try modelContext.fetch(request)
            print("Found \(transactions.count) transactions")
            
            var csvString = "Merchant,Amount,Account,Date,Note\n"
            
            for transaction in transactions {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                let merchant = escapeCSVField(transaction.merchant)
                let amount = String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber))
                let account = escapeCSVField(transaction.card?.name ?? "Unknown")
                let dateString = dateFormatter.string(from: transaction.date)
                let note = escapeCSVField(transaction.note ?? "")
                
                csvString += "\(merchant),\(amount),\(account),\(dateString),\(note)\n"
            }
            
            print("Generated CSV content length: \(csvString.count)")
            print("CSV content preview: \(String(csvString.prefix(200)))")
            
            return csvString
        } catch {
            print("Error exporting to CSV: \(error)")
            return ""
        }
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // Escape commas and quotes in CSV fields
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    func importFromCSV(_ csvString: String) {
        let lines = csvString.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue } // Skip header and empty lines
            
            let components = parseCSVLine(line)
            guard components.count >= 4 else { continue }
            
            let merchant = components[0]
            let amountString = components[1]
            let accountName = components[2]
            let dateString = components[3]
            let note = components.count > 4 ? components[4] : nil
            
            guard let amount = Decimal(string: amountString) else { continue }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            var matchedCard: Card? = nil
            if !accountName.isEmpty && accountName != "Unknown" {
                // Find matching card by exact name
                let cardRequest = FetchDescriptor<Card>(
                    predicate: #Predicate { card in
                        card.name == accountName
                    }
                )
                do {
                    matchedCard = try modelContext.fetch(cardRequest).first
                } catch {
                    print("Error fetching card for name \(accountName): \(error)")
                }
            }
            
            let transaction = Transaction(
                merchant: merchant,
                amount: amount,
                date: date,
                category: nil, // Category not in new format
                note: note?.isEmpty == true ? nil : note,
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
    
    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                // Look ahead safely to see if this is an escaped quote ("")
                let nextIndex = line.index(after: i)
                if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    // Escaped quote
                    currentField += "\""
                    i = line.index(after: nextIndex)
                } else {
                    // Toggle quote state
                    inQuotes.toggle()
                    i = nextIndex
                }
            } else if char == "," && !inQuotes {
                // Field separator
                components.append(currentField)
                currentField = ""
                i = line.index(after: i)
            } else {
                currentField.append(char)
                i = line.index(after: i)
            }
        }
        
        // Add the last field
        components.append(currentField)
        
        return components
    }
}
