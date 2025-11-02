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
    @State private var minimumSpendingByDayOfMonth: Int
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: Field?

    // Focus fields for this form
    private enum Field {
        case name
        case minSpendAmount
    }
    
    private let rewardTypes = ["none", "miles", "cashback"]
    
    init(card: Card? = nil) {
        self.cardToEdit = card
        if let card {
            _cardName = State(initialValue: card.name)
            _rewardType = State(initialValue: card.rewardType)
            _hasMinimumSpending = State(initialValue: card.hasMinimumSpending)
            _minimumSpendingAmount = State(initialValue: String(format: "%.0f", Double(truncating: card.minimumSpendingAmount as NSDecimalNumber)))
            _minimumSpendingByDayOfMonth = State(initialValue: card.minimumSpendingByDayOfMonth)
        } else {
            _cardName = State(initialValue: "")
            _rewardType = State(initialValue: "none")
            _hasMinimumSpending = State(initialValue: false)
            _minimumSpendingAmount = State(initialValue: "")
            _minimumSpendingByDayOfMonth = State(initialValue: 1)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    LabeledContent {
                        TextField("", text: $cardName)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .name)
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
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .minSpendAmount)
                                    .onChange(of: minimumSpendingAmount) { _, newValue in
                                        // Allow only digits (no decimals)
                                        minimumSpendingAmount = newValue.filter { $0.isNumber }
                                    }
                            } label: {
                                Text("Need to spend")
                            }
                            
                            LabeledContent {
                                Picker("", selection: $minimumSpendingByDayOfMonth) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("Day \(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.wheel)
                            } label: {
                                Text("By Day \(minimumSpendingByDayOfMonth) of each month")
                            }
                            
                            Text("Your mininum spending resets on this day each month. Try to reach the minimum spending amount before then to earn rewards from your card issuer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
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
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
            .onAppear{
                if (cardToEdit == nil) {
                    focusedField = .name
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
                editing.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            }
            do { try modelContext.save(); dismiss() } catch { print("Error saving card: \(error)") }
        } else {
            // Create new
            let newMinimumSpendingAmount: Decimal = {
                if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) { return parsed }
                return 0
            }()
            let stmtDay: Int = hasMinimumSpending ? minimumSpendingByDayOfMonth : 1
            let card = Card(
                name: cardName,
                minimumSpendingAmount: newMinimumSpendingAmount,
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
