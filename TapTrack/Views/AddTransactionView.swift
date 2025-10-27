//
//  AddTransactionView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var cards: [Card]
    
    let initialSelectedCard: Card?
    
    @State private var merchant = ""
    @State private var amount = ""
    @State private var selectedCard: Card?
    @State private var category = ""
    @State private var note = ""
    @State private var transactionDate = Date()
    
    private let categories = ["Groceries", "Dining Out", "Transport", "Entertainment", "Shopping", "Other"]
    
    init(selectedCard: Card? = nil) {
        self.initialSelectedCard = selectedCard
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
                    
                    DatePicker("Date", selection: $transactionDate, displayedComponents: .date)
                }
                
                Section("Card") {
                    Picker("Select Card", selection: $selectedCard) {
                        Text("Select a card").tag(nil as Card?)
                        ForEach(cards) { card in
                            Text("\(card.name) (....\(card.last4))").tag(card as Card?)
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
            }
            .navigationTitle("Add Transaction")
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
                    .disabled(merchant.isEmpty || amount.isEmpty || selectedCard == nil)
                }
            }
        }
        .onAppear {
            if let card = initialSelectedCard {
                self.selectedCard = card
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount),
              let card = selectedCard else { return }
        
        let transaction = Transaction(
            merchant: merchant,
            amount: amountDecimal,
            date: transactionDate,
            category: category.isEmpty ? nil : category,
            note: note.isEmpty ? nil : note,
            card: card
        )
        
        modelContext.insert(transaction)
        card.currentSpent += amountDecimal
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving transaction: \(error)")
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(ModelContainer.createMockContainer())
}
