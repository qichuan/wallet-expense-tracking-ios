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

    @State private var cardName: String
    @State private var rewardType: RewardType
    @State private var hasMinimumSpending: Bool
    @State private var minimumSpendingAmount: String
    @State private var minimumSpendingByDayOfMonth: Int
    @State private var showingDeleteAlert = false

    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool

    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"

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
            _rewardType = State(initialValue: .none)
            _hasMinimumSpending = State(initialValue: false)
            _minimumSpendingAmount = State(initialValue: "")
            _minimumSpendingByDayOfMonth = State(initialValue: 1)
        }
    }

    private var isValid: Bool {
        !cardName.trimmingCharacters(in: .whitespaces).isEmpty
        && !(hasMinimumSpending && minimumSpendingAmount.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        detailsSection
                        rewardSection
                        minimumSpendingSection

                        if cardToEdit != nil {
                            DestructiveButton(title: "Delete Card") {
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
            .navigationTitle(cardToEdit == nil ? "Add Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear {
                if cardToEdit == nil {
                    nameFocused = true
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Card", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteCard() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this card? This action cannot be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var detailsSection: some View {
        FormSection("Card Details") {
            FormTextFieldRow(
                title: "Name",
                placeholder: "DBS Altitude Visa",
                text: $cardName,
                isFocused: $nameFocused
            )
        }
    }

    @ViewBuilder
    private var rewardSection: some View {
        FormSection("Reward Type") {
            rewardSelector
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var rewardSelector: some View {
        HStack(spacing: 8) {
            ForEach(RewardType.allCases, id: \.self) { type in
                rewardButton(type)
            }
        }
    }

    @ViewBuilder
    private func rewardButton(_ type: RewardType) -> some View {
        let isSelected = rewardType == type
        Button {
            rewardType = type
        } label: {
            Text(title(for: type))
                .font(AppTypography.filterChip)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? color(for: type) : AppColors.backgroundCardSoft)
                )
        }
        .buttonStyle(.plain)
    }

    private func title(for type: RewardType) -> String {
        switch type {
        case .miles: return "Miles"
        case .cashback: return "Cash"
        case .none: return "None"
        }
    }

    private func color(for type: RewardType) -> Color {
        switch type {
        case .miles: return AppColors.rewardMiles
        case .cashback: return AppColors.rewardCash
        case .none: return AppColors.accent
        }
    }

    @ViewBuilder
    private var minimumSpendingSection: some View {
        FormSection("Minimum Spending") {
            FormToggleRow(title: "Track minimum spend", isOn: $hasMinimumSpending)

            if hasMinimumSpending {
                FormDivider()
                amountRow
                FormDivider()
                statementDayRow

                Text("Your minimum spending resets on this day each month. Reach the minimum before then to earn rewards from your card issuer.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private var amountRow: some View {
        HStack(spacing: 12) {
            Text("Target")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(CurrencyUtils.symbol(for: defaultCurrencyCode))
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textSecondary)
            TextField("0", text: $minimumSpendingAmount, prompt: Text("0").foregroundColor(AppColors.textTertiary))
                .keyboardType(.numberPad)
                .focused($amountFocused)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .onChange(of: minimumSpendingAmount) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue { minimumSpendingAmount = filtered }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statementDayRow: some View {
        HStack(spacing: 12) {
            Text("Statement day")
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Menu {
                Picker("", selection: $minimumSpendingByDayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Day \(minimumSpendingByDayOfMonth)")
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") { saveCard() }
                .font(AppTypography.navButton)
                .foregroundColor(isValid ? AppColors.accent : AppColors.textTertiary)
                .disabled(!isValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                nameFocused = false
                amountFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Actions

    private func saveCard() {
        if let editing = cardToEdit {
            editing.name = cardName
            editing.rewardType = rewardType
            editing.hasMinimumSpending = hasMinimumSpending
            if hasMinimumSpending, let parsed = Decimal(string: minimumSpendingAmount) {
                editing.minimumSpendingAmount = parsed
                editing.minimumSpendingByDayOfMonth = minimumSpendingByDayOfMonth
            }
            do {
                try modelContext.save()
                AnalyticsTracker.edit("card", [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending
                ])
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch { print("Error saving card: \(error)") }
        } else {
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
            do {
                try modelContext.save()
                AnalyticsTracker.log(AnalyticsTracker.Event.cardAdded, [
                    "reward_type": String(describing: rewardType),
                    "has_min_spend": hasMinimumSpending,
                    "statement_day": stmtDay
                ])
                WidgetDataWriter.refresh(using: modelContext)
                dismiss()
            } catch { print("Error saving card: \(error)") }
        }
    }

    private func deleteCard() {
        guard let editing = cardToEdit else { return }
        let rewardTypeString = String(describing: editing.rewardType)
        for transaction in editing.transactions {
            transaction.card = nil
        }
        modelContext.delete(editing)
        do {
            try modelContext.save()
            AnalyticsTracker.log(AnalyticsTracker.Event.cardDeleted, [
                "reward_type": rewardTypeString
            ])
            WidgetDataWriter.refresh(using: modelContext)
            dismiss()
        } catch { print("Error deleting card: \(error)") }
    }
}

#Preview {
    CardFormView()
        .modelContainer(ModelContainer.createMockContainer())
}
