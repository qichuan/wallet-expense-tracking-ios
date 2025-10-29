//
//  EditTransactionView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    let transaction: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var cards: [Card]
    
    @State private var merchant: String
    @State private var amount: String
    @State private var selectedCard: Card?
    @State private var category: String
    @State private var note: String
    @State private var transactionDate: Date
    @State private var showingDeleteAlert = false
    
    private let categories = MerchantUtils.defaultCategories
    
    init(transaction: Transaction) {
        self.transaction = transaction
        self._merchant = State(initialValue: transaction.merchant)
        self._amount = State(initialValue: String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber)))
        self._selectedCard = State(initialValue: transaction.card)
        self._category = State(initialValue: MerchantUtils.normalizedCategory(for: transaction.category))
        self._note = State(initialValue: transaction.note ?? "")
        self._transactionDate = State(initialValue: transaction.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Transaction Details") {
                    TextField("Merchant", text: $merchant)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Amount", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { _, newValue in
                            amount = formatAmountInput(newValue)
                        }
                    
                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Card (Optional)") {
                    Picker("Select Card", selection: $selectedCard) {
                        Text("No card selected").tag(nil as Card?)
                        ForEach(cards) { card in
                            Text(card.name).tag(card as Card?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Note") {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Delete Transaction") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }
    
    private func formatAmountInput(_ input: String) -> String {
        // Remove any non-numeric characters except decimal point
        let filtered = input.filter { $0.isNumber || $0 == "." }
        
        // Split by decimal point
        let parts = filtered.components(separatedBy: ".")
        
        // If there's a decimal part, limit to 2 digits
        if parts.count > 1 {
            let integerPart = parts[0]
            let decimalPart = String(parts[1].prefix(2))
            return "\(integerPart).\(decimalPart)"
        }
        
        return filtered
    }
    
    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        
        // Update the original amount on the card if it changed
        if let oldCard = transaction.card {
            oldCard.currentSpent -= transaction.amount
        }
        
        // Update transaction properties
        transaction.merchant = merchant
        transaction.amount = amountDecimal
        transaction.date = transactionDate
        transaction.category = category.isEmpty ? nil : category
        transaction.note = note.isEmpty ? nil : note
        transaction.card = selectedCard
        
        // Add the new amount to the selected card (if any)
        if let newCard = selectedCard {
            newCard.currentSpent += amountDecimal
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving transaction: \(error)")
        }
    }
    
    private func deleteTransaction() {
        // Remove the amount from the card
        if let card = transaction.card {
            card.currentSpent -= transaction.amount
        }
        
        modelContext.delete(transaction)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting transaction: \(error)")
        }
    }
}

#Preview {
    let transaction = Transaction(
        merchant: "Apple Store",
        amount: 999.00,
        date: Date(),
        category: "Shopping"
    )
    
    return EditTransactionView(transaction: transaction)
        .modelContainer(ModelContainer.createMockContainer())
}
