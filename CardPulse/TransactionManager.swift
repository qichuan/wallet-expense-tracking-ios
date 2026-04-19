//
//  TransactionManager.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import SwiftData
import Combine
import WidgetKit

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
            refreshWidgetData()
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
            refreshWidgetData()
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
            refreshWidgetData()
        } catch {
            errorMessage = "Error deleting card: \(error.localizedDescription)"
            print("Error deleting card: \(error)")
        }

        isLoading = false
    }

    private func refreshWidgetData() {
        WidgetDataWriter.refresh(using: modelContext)
    }
}
