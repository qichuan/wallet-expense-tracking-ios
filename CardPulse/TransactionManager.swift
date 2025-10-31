//
//  TransactionManager.swift
//  CardPulse
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
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error saving transaction: \(error.localizedDescription)"
            print("Error saving transaction: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        isLoading = true
        errorMessage = nil
        
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
            
            var csvString = "Merchant,Amount,Category,Card,Date,Note\n"
            
            for transaction in transactions {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                let merchant = escapeCSVField(transaction.merchant)
                let amount = String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber))
                let category = escapeCSVField(transaction.category ?? "")
                let cardName = escapeCSVField(transaction.card?.name ?? "")
                let dateString = dateFormatter.string(from: transaction.date)
                let note = escapeCSVField(transaction.note ?? "")
                
                csvString += "\(merchant),\(amount),\(category),\(cardName),\(dateString),\(note)\n"
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
        // Escape quotes by doubling them per RFC 4180
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        // Wrap in quotes if field contains comma, quote, newline or carriage return
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    func importFromCSV(_ csvString: String) {
        let lines = csvString.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue } // Skip header and empty lines
            
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }
            
            let merchant = components[0]
            let amountString = components[1]
            let category = components[2].isEmpty ? nil : components[2]
            let cardName = components[3]
            let dateString = components[4]
            let note = components.count > 5 ? components[5] : nil
            
            guard let amount = Decimal(string: amountString) else { continue }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            var matchedCard: Card? = nil
            if !cardName.isEmpty {
                // Find matching card by exact name
                let cardRequest = FetchDescriptor<Card>(
                    predicate: #Predicate { card in
                        card.name == cardName
                    }
                )
                do {
                    matchedCard = try modelContext.fetch(cardRequest).first
                } catch {
                    print("Error fetching card for name \(cardName): \(error)")
                }
                // Create card if missing (override duplicates by reusing existing)
                if matchedCard == nil {
                    let newCard = Card(
                        name: cardName,
                        minimumSpendingAmount: 0,
                        rewardType: "miles"
                    )
                    modelContext.insert(newCard)
                    matchedCard = newCard
                }
            }
            
            let transaction = Transaction(
                merchant: merchant,
                amount: amount,
                date: date,
                category: category,
                note: note?.isEmpty == true ? nil : note,
                card: matchedCard
            )
            
            modelContext.insert(transaction)
            
            // current spent is derived from transactions; no direct mutation
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
                // Trim trailing carriage return if present
                let cleaned = currentField.hasSuffix("\r") ? String(currentField.dropLast()) : currentField
                components.append(cleaned)
                currentField = ""
                i = line.index(after: i)
            } else {
                currentField.append(char)
                i = line.index(after: i)
            }
        }
        
        // Add the last field
        let cleaned = currentField.hasSuffix("\r") ? String(currentField.dropLast()) : currentField
        components.append(cleaned)
        
        return components
    }
}
