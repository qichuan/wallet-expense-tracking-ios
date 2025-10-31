//
//  CardFormView.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import SwiftUI
import SwiftData

struct CardFormView: View {
    let cardToEdit: Card?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var cardName: String
    @State private var rewardType: String
    @State private var hasMinimumSpending: Bool
    @State private var minimumSpendingAmount: String
    @State private var statementDay: Int
    @State private var showingDeleteAlert = false
    
    private let rewardTypes = ["none", "miles", "cashback"]
    
    init(card: Card? = nil) {
        self.cardToEdit = card
        if let card {
            _cardName = State(initialValue: card.name)
            _rewardType = State(initialValue: card.rewardType)
            _hasMinimumSpending = State(initialValue: card.hasMinimumSpending)
            _minimumSpendingAmount = State(initialValue: String(format: "%.0f", Double(truncating: card.minimumSpendingAmount as NSDecimalNumber)))
            _statementDay = State(initialValue: card.minimumSpendingByDayOfMonth)
        } else {
            _cardName = State(initialValue: "")
            _rewardType = State(initialValue: "none")
            _hasMinimumSpending = State(initialValue: false)
            _minimumSpendingAmount = State(initialValue: "")
            _statementDay = State(initialValue: 1)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    LabeledContent {
                        TextField("", text: $cardName)
                            .textFieldStyle(.roundedBorder)
                    } label: {
                        Text("Card Name")
                    }
                    
                    Picker("Reward Type", selection: $rewardType) {
                        ForEach(rewardTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    
                    Toggle("Minimum Spending", isOn: $hasMinimumSpending)
                    
                    if hasMinimumSpending {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent {
                                TextField("", text: $minimumSpendingAmount)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                            } label: {
                                Text("Need to spend")
                            }
                            
                            DayOfMonthPicker(selectedDay: $statementDay)
                        }
                        .padding(.leading, 20)
                    }
                }
                
                if cardToEdit != nil {
                    Section {
                        Button("Delete Card") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(cardToEdit == nil ? "Add Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveCard() }
                        .disabled(cardName.isEmpty || (hasMinimumSpending && minimumSpendingAmount.isEmpty))
                }
            }
        }
        .alert("Delete Card", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteCard()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
    }
    
    private func saveCard() {
        if let editing = cardToEdit {
            // Update existing
            editing.name = cardName
            editing.rewardType = rewardType
            editing.hasMinimumSpending = hasMinimumSpending
            if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) {
                editing.minimumSpendingAmount = parsed
                editing.minimumSpendingByDayOfMonth = statementDay
            } else {
                editing.minimumSpendingAmount = 0
                editing.minimumSpendingByDayOfMonth = 1
            }
            do { try modelContext.save(); dismiss() } catch { print("Error saving card: \(error)") }
        } else {
            // Create new
            let goalAmount: Decimal = {
                if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) { return parsed }
                return 0
            }()
            let stmtDay: Int = hasMinimumSpending ? statementDay : 1
            let card = Card(
                name: cardName,
                minimumSpendingAmount: goalAmount,
                hasMinimumSpending: hasMinimumSpending,
                rewardType: rewardType,
                minimumSpendingByDayOfMonth: stmtDay
            )
            modelContext.insert(card)
            do { try modelContext.save(); dismiss() } catch { print("Error saving card: \(error)") }
        }
    }
    
    private func deleteCard() {
        guard let editing = cardToEdit else { return }
        modelContext.delete(editing)
        do { try modelContext.save(); dismiss() } catch { print("Error deleting card: \(error)") }
    }
}

#Preview {
    CardFormView()
        .modelContainer(ModelContainer.createMockContainer())
}


