//
//  TransactionFormView.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import SwiftUI
import SwiftData
import FirebaseAnalytics

struct TransactionFormView: View {
    let transactionToEdit: Transaction?
    
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
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case merchant, amount, note
    }
    
    private let categories = MerchantUtils.defaultCategories
    
    init(transaction: Transaction? = nil) {
        self.transactionToEdit = transaction
        if let transaction {
            _merchant = State(initialValue: transaction.merchant)
            _amount = State(initialValue: String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber)))
            _selectedCard = State(initialValue: transaction.card)
            _category = State(initialValue: MerchantUtils.normalizedCategory(for: transaction.category))
            _note = State(initialValue: transaction.note ?? "")
            _transactionDate = State(initialValue: transaction.date)
        } else {
            _merchant = State(initialValue: "")
            _amount = State(initialValue: "")
            _selectedCard = State(initialValue: nil)
            _category = State(initialValue: MerchantUtils.defaultCategories.first ?? "Other")
            _note = State(initialValue: "")
            _transactionDate = State(initialValue: Date())
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Transaction Details") {
                    LabeledContent {
                        TextField("", text: $merchant)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .merchant)
                    } label: {
                        Text("Merchant")
                    }
                    
                    LabeledContent {
                        TextField("", text: $amount)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amount) { _, newValue in
                                amount = formatAmountInput(newValue)
                            }
                    } label: {
                        Text("Amount")
                    }
                    
                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: transactionDate) { _, _ in
                            focusedField = nil
                        }
                    
                    Picker("Card", selection: $selectedCard) {
                        Text("No card selected").tag(nil as Card?)
                        ForEach(cards) { card in
                            Text(card.name).tag(card as Card?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedCard) { _, _ in
                        focusedField = nil
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: category) { _, _ in
                        focusedField = nil
                    }
                }
                
                Section("Note") {
                    TextField("This transaction is about...", text: $note, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .note)
                }
                
                if transactionToEdit != nil {
                    Section {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Text("Delete Transaction")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                    }
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    focusedField = nil
                }
            )
            .navigationTitle(transactionToEdit == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveTransaction() }
                        .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
            .onAppear{
                if (transactionToEdit == nil) {
                    focusedField = .merchant
                }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }
    
    private func formatAmountInput(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == "." }
        let parts = filtered.components(separatedBy: ".")
        if parts.count > 1 {
            let integerPart = parts[0]
            let decimalPart = String(parts[1].prefix(2))
            return "\(integerPart).\(decimalPart)"
        }
        return filtered
    }
    
    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        if let editing = transactionToEdit {
            editing.merchant = merchant
            editing.amount = amountDecimal
            editing.date = transactionDate
            editing.category = category.isEmpty ? nil : category
            editing.note = note.isEmpty ? nil : note
            editing.card = selectedCard
            do { try modelContext.save(); WidgetDataWriter.refresh(using: modelContext); dismiss() }
            catch { print("Error saving transaction: \(error)") }
        } else {
            let transaction = Transaction(
                merchant: merchant,
                amount: amountDecimal,
                date: transactionDate,
                category: category.isEmpty ? nil : category,
                note: note.isEmpty ? nil : note,
                card: selectedCard
            )
            modelContext.insert(transaction)
            Analytics.logEvent("add_wallet_transaction", parameters: [
                "type": "manual",
                "merchant": merchant,
                "amount": amount,
            ])
            do { try modelContext.save(); WidgetDataWriter.refresh(using: modelContext); dismiss() }
            catch { print("Error saving transaction: \(error)") }
        }
    }

    private func deleteTransaction() {
        guard let editing = transactionToEdit else { return }
        modelContext.delete(editing)
        do { try modelContext.save(); WidgetDataWriter.refresh(using: modelContext); dismiss() }
        catch { print("Error deleting transaction: \(error)") }
    }
}

#Preview {
    TransactionFormView()
        .modelContainer(ModelContainer.createMockContainer())
}


