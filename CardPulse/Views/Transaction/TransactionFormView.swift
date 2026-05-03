//
//  TransactionFormView.swift
//  CardPulse
//
//  Created by Assistant on 31/10/25.
//

import SwiftUI
import SwiftData

struct TransactionFormView: View {
    let transactionToEdit: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var cards: [Card]
    @Query(sort: \SpendingCategory.sortOrder) private var categoryRecords: [SpendingCategory]

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = "SGD,MYR,HKD,USD,EUR"
    @AppStorage("customCurrenciesRaw") private var customCurrenciesRaw = ""

    @State private var merchant: String
    @State private var amount: String
    @State private var currency: String
    @State private var selectedCard: Card?
    @State private var category: String
    @State private var note: String
    @State private var transactionDate: Date
    @State private var isRecurring: Bool
    @State private var showingDeleteAlert = false

    @FocusState private var merchantFocused: Bool
    @FocusState private var amountFocused: Bool
    @FocusState private var noteFocused: Bool

    private var enabledCurrencies: [CurrencyInfo] {
        let enabled = CurrencyUtils.enabledCurrencies(fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw)
        if !currency.isEmpty, !enabled.contains(where: { $0.code == currency }),
           let info = CurrencyUtils.info(for: currency) {
            return [info] + enabled
        }
        return enabled
    }

    /// Names shown in the category picker.
    /// Uses the @Query'd `SpendingCategory` list (falling back to `MerchantUtils.defaultCategories`
    /// before the store has been seeded). If the currently-selected category is not in the
    /// list (orphan — e.g. legacy "Dining Out" or a user-deleted custom), it's prepended so
    /// the Picker can still render it.
    private var categoryNames: [String] {
        let stored = categoryRecords.map { $0.name }
        let base = stored.isEmpty ? MerchantUtils.defaultCategories : stored
        if !category.isEmpty,
           !base.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return [category] + base
        }
        return base
    }

    init(transaction: Transaction? = nil) {
        self.transactionToEdit = transaction
        if let transaction {
            _merchant = State(initialValue: transaction.merchant)
            _amount = State(initialValue: String(format: "%.2f", Double(truncating: transaction.amount as NSDecimalNumber)))
            _currency = State(initialValue: transaction.currency)
            _selectedCard = State(initialValue: transaction.card)
            _category = State(initialValue: transaction.category ?? "Other")
            _note = State(initialValue: transaction.note ?? "")
            _transactionDate = State(initialValue: transaction.date)
            _isRecurring = State(initialValue: transaction.isRecurring)
        } else {
            _merchant = State(initialValue: "")
            _amount = State(initialValue: "")
            _currency = State(initialValue: "")
            _selectedCard = State(initialValue: nil)
            _category = State(initialValue: "Other")
            _note = State(initialValue: "")
            _transactionDate = State(initialValue: Date())
            _isRecurring = State(initialValue: false)
        }
    }

    private var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty
        && !amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        merchantSection
                        amountSection
                        detailsSection
                        recurringSection
                        noteSection

                        if transactionToEdit != nil {
                            DestructiveButton(title: "Delete Transaction") {
                                showingDeleteAlert = true
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(transactionToEdit == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear {
                if transactionToEdit == nil {
                    merchantFocused = true
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var merchantSection: some View {
        FormSection("Merchant") {
            FormTextFieldRow(
                title: "Name",
                placeholder: "Apple Store",
                text: $merchant,
                isFocused: $merchantFocused
            )
        }
    }

    @ViewBuilder
    private var amountSection: some View {
        FormSection("Amount") {
            HStack(spacing: 12) {
                Text(CurrencyUtils.symbol(for: currency.isEmpty ? defaultCurrencyCode : currency))
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(minWidth: 36, alignment: .leading)

                TextField("", text: $amount, prompt: Text("0.00").foregroundColor(AppColors.textTertiary))
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .onChange(of: amount) { _, newValue in
                        let formatted = formatAmountInput(newValue)
                        if formatted != newValue { amount = formatted }
                    }

                Menu {
                    Picker("", selection: $currency) {
                        Text("Default (\(defaultCurrencyCode))").tag("")
                        ForEach(enabledCurrencies) { info in
                            Text("\(info.name) (\(info.code))").tag(info.code)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currency.isEmpty ? defaultCurrencyCode : currency)
                            .font(AppTypography.pillBold)
                        Image(systemName: "chevron.down")
                            .font(AppTypography.chevronTinyBold)
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.accentSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        FormSection("Details") {
            FormDateRow(title: "Date", date: $transactionDate)
            FormDivider()

            cardRow
            FormDivider()

            categoryRow
        }
    }

    @ViewBuilder
    private var cardRow: some View {
        HStack(spacing: 12) {
            Text("Card")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $selectedCard) {
                    Text("None").tag(nil as Card?)
                    ForEach(cards) { card in
                        Text(card.name).tag(card as Card?)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCard?.name ?? "None")
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.chevronTiny)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var categoryRow: some View {
        HStack(spacing: 12) {
            Text("Category")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $category) {
                    ForEach(categoryNames, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(MerchantUtils.color(for: category, in: categoryRecords))
                        .frame(width: 8, height: 8)
                    Text(category)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppTypography.chevronTiny)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var recurringSection: some View {
        FormSection("Recurring") {
            FormToggleRow(title: "Repeat monthly", isOn: $isRecurring)
            if isRecurring {
                Text(recurringHelpText)
                    .font(AppTypography.rowMeta)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var recurringHelpText: String {
        let day = Calendar.current.component(.day, from: transactionDate)
        let ordinal = Self.ordinalDay(day)
        if day >= 29 {
            return "Repeats on the \(ordinal) each month (or the last day in shorter months). Turn off to stop the chain."
        }
        return "Repeats on the \(ordinal) each month. Turn off to stop the chain."
    }

    private static func ordinalDay(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    @ViewBuilder
    private var noteSection: some View {
        FormSection("Note") {
            FormNoteEditor(
                text: $note,
                placeholder: "This transaction is about…",
                isFocused: $noteFocused
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") { saveTransaction() }
                .font(AppTypography.navButton)
                .foregroundColor(isValid ? AppColors.accent : AppColors.textTertiary)
                .disabled(!isValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                merchantFocused = false
                amountFocused = false
                noteFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Actions

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
            editing.currency = currency
            editing.date = transactionDate
            editing.category = category.isEmpty ? nil : category
            editing.note = note.isEmpty ? nil : note
            editing.card = selectedCard
            editing.isRecurring = isRecurring
            do { try modelContext.save(); WidgetDataWriter.refresh(using: modelContext); dismiss() }
            catch { print("Error saving transaction: \(error)") }
        } else {
            let transaction = Transaction(
                merchant: merchant,
                amount: amountDecimal,
                date: transactionDate,
                category: category.isEmpty ? nil : category,
                note: note.isEmpty ? nil : note,
                card: selectedCard,
                currency: currency,
                isRecurring: isRecurring
            )
            modelContext.insert(transaction)
            AnalyticsTracker.log("add_wallet_transaction", [
                "type": "manual",
                "merchant": merchant,
                "amount": amount,
                "currency": currency
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
