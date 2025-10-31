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
    @State private var enableGoalFields: Bool
    @State private var totalGoal: String
    @State private var statementDay: Int
    @State private var showingDeleteAlert = false
    
    private let rewardTypes = ["none", "miles", "cashback"]
    
    init(card: Card? = nil) {
        self.cardToEdit = card
        if let card {
            _cardName = State(initialValue: card.name)
            _rewardType = State(initialValue: card.rewardType)
            _enableGoalFields = State(initialValue: true)
            _totalGoal = State(initialValue: String(format: "%.0f", Double(truncating: card.totalGoal as NSDecimalNumber)))
            _statementDay = State(initialValue: card.statementDay)
        } else {
            _cardName = State(initialValue: "")
            _rewardType = State(initialValue: "none")
            _enableGoalFields = State(initialValue: false)
            _totalGoal = State(initialValue: "")
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
                    
                    Toggle("\(cardToEdit == nil ? "Set goal and statement day" : "Edit goal and statement day")", isOn: $enableGoalFields)
                    
                    if enableGoalFields {
                        LabeledContent {
                            TextField("", text: $totalGoal)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                        } label: {
                            Text("Minimum Spending")
                        }
                        
                        DayOfMonthPicker(selectedDay: $statementDay)
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
                        .disabled(cardName.isEmpty || (enableGoalFields && totalGoal.isEmpty))
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
            if enableGoalFields, let parsed = Decimal(string: totalGoal) {
                editing.totalGoal = parsed
                editing.statementDay = statementDay
            }
            do { try modelContext.save(); dismiss() } catch { print("Error saving card: \(error)") }
        } else {
            // Create new
            let goalAmount: Decimal = {
                if enableGoalFields, let parsed = Decimal(string: totalGoal) { return parsed }
                return 0
            }()
            let stmtDay: Int = enableGoalFields ? statementDay : 1
            let card = Card(
                name: cardName,
                totalGoal: goalAmount,
                goalDeadline: Date(),
                rewardType: rewardType,
                statementDay: stmtDay
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


