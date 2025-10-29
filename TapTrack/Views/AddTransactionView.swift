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
    @State private var category = MerchantUtils.defaultCategories.first ?? "Other"
    @State private var note = ""
    @State private var transactionDate = Date()
    
    private let categories = MerchantUtils.defaultCategories
    
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
                        .onChange(of: amount) { _, newValue in
                            amount = formatAmountInput(newValue)
                        }
                    
                    DatePicker("Date", selection: $transactionDate, displayedComponents: .date)
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
                    .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
        }
        .onAppear {
            if let card = initialSelectedCard {
                self.selectedCard = card
            }
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
        
        let transaction = Transaction(
            merchant: merchant,
            amount: amountDecimal,
            date: transactionDate,
            category: category.isEmpty ? nil : category,
            note: note.isEmpty ? nil : note,
            card: selectedCard
        )
        
        modelContext.insert(transaction)
        
        // Only update card spending if a card is selected
        if let card = selectedCard {
            card.currentSpent += amountDecimal
        }
        
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
